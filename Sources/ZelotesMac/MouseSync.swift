import Foundation
import Observation
import OSLog
import ZelotesKit

/// The saved presets, and the writes that keep the mouse's profiles in step with them.
@MainActor
@Observable
final class MouseSync {
    enum WriteState: Equatable {
        case idle
        case writing
        case failed(String)
    }

    private(set) var library: PresetLibrary
    private(set) var isMouseConnected = false
    private(set) var writeState = WriteState.idle
    /// Why macOS did not take the pointer settings, while it does not.
    private(set) var pointerError: String?
    private(set) var pointerAgentState = PointerAgent.State.off

    @ObservationIgnored private let store: MappingStore
    @ObservationIgnored private let connection = MouseConnection()
    @ObservationIgnored private let pointerTuner = PointerTuner()
    @ObservationIgnored private let log = Logger(subsystem: "local.zelotes-mac", category: "mouse")
    @ObservationIgnored private var lastWork: Task<Void, Never>?
    /// What the pointer filter has now, or `nil` when that is unknown.
    @ObservationIgnored private var appliedPointer: PointerTarget?
    @ObservationIgnored private var pointerSearch: Task<Void, Never>?
    @ObservationIgnored private var pointerAgentIsNeeded: Bool?
    @ObservationIgnored private var pointerAgentWork: Task<Void, Never>?
    @ObservationIgnored private let isPreview: Bool

    /// A preview shows a connected mouse and leaves the mouse, the pointer and the launch agent alone.
    init(store: MappingStore, isPreview: Bool = false) {
        self.store = store
        self.isPreview = isPreview
        let saved = store.load()
        library = saved ?? PresetLibrary()
        if saved == nil {
            keepUnusableSavedFile()
        }
        guard !isPreview else {
            isMouseConnected = true
            pointerAgentState = .on
            return
        }
        connection.onChange = { [weak self] in self?.connectionChanged() }
        do {
            try connection.start()
        } catch {
            fail(error)
        }
        updatePointerAgent()
        applyPointerOnceMouseAppears()
    }

    @discardableResult
    func changeAndSave<Result>(_ body: (inout PresetLibrary) -> Result) -> Result {
        let result = body(&library)
        persist()
        updatePointer()
        return result
    }

    /// Runs `work` once all work enqueued before it has finished, so writes reach the mouse in the order asked for.
    func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = lastWork
        lastWork = Task {
            await previous?.value
            await work()
        }
    }

    func waitUntilIdle() async {
        await lastWork?.value
    }

    /// Writes `preset` into `profile`. A preset leaving the other profile trades places with the one it displaces.
    func place(_ preset: Preset, in profile: MouseProfile) async {
        let holder = library.profile(holding: preset.id)
        let origin = holder == profile ? nil : holder
        let displaced = library.preset(in: profile)
        await writeToMouse { writer in
            try await writer.write(.everything(of: preset), to: profile)
            self.library.recordWrite(of: preset, to: profile)
            self.library.recordActivation(of: profile)
            guard let origin else { return }
            self.library.clearRecord(of: origin)
            guard let displaced else { return }
            try await writer.write(.everything(of: displaced), to: origin)
            self.library.recordWrite(of: displaced, to: origin)
            self.library.recordActivation(of: origin)
            try await writer.select(profile)
            self.library.recordActivation(of: profile)
        }
    }

    /// Makes `profile` the active one on the mouse. Does nothing while the mouse is not connected.
    func makeActive(_ profile: MouseProfile) async {
        guard isMouseConnected else { return }
        await writeToMouse { writer in
            try await writer.select(profile)
            self.library.recordActivation(of: profile)
        }
    }

    /// Writes the parts of the saved preset of `profile` that the mouse holds in an earlier version.
    /// Buttons without a Left Click are held back unless `evenWithoutLeftClick`, so the mouse is not left
    /// unable to click.
    func update(_ profile: MouseProfile, evenWithoutLeftClick: Bool) async {
        guard isMouseConnected, let preset = library.preset(in: profile),
              let pending = library.pendingUpdate(of: profile) else { return }
        guard evenWithoutLeftClick || pending.buttons?.hasLeftClick != false else { return }
        await writeToMouse { writer in
            try await writer.write(pending, to: profile)
            self.library.recordWrite(of: preset, to: profile)
            self.library.recordActivation(of: profile)
        }
    }

    /// Switches the mouse to `stage` of `profile`. Does nothing while the mouse is not connected.
    func selectStage(_ stage: Int, in profile: MouseProfile) async {
        guard isMouseConnected else { return }
        await writeToMouse { writer in
            try await writer.selectStage(stage, of: profile)
            self.library.recordStageSelection(stage, in: profile)
            self.library.recordActivation(of: profile)
        }
    }

    private func writeToMouse(_ work: (ProfileWriter) async throws -> Void) async {
        guard let channel = connection.configurationChannel else {
            fail(MouseAccessError.notConnected)
            return
        }
        writeState = .writing
        do {
            try await work(ProfileWriter(transport: channel))
            writeState = .idle
            log.info("Updated the mouse")
        } catch {
            fail(error)
        }
        persist()
        updatePointer()
    }

    /// The user can turn the agent off and on in System Settings at any time, so this reads it again.
    func refreshPointerAgentState() {
        pointerAgentIsNeeded = nil
        updatePointer()
    }

    private func updatePointer() {
        guard !isPreview else { return }
        updatePointerAgent()
        applyPointerTargetIfChanged()
    }

    private func applyPointerTargetIfChanged() {
        let target = pointerTargetToApply
        if target != appliedPointer {
            applyPointer(target)
        }
    }

    /// The pointer settings in use, or macOS's own while the agent that keeps them is not allowed to run.
    private var pointerTargetToApply: PointerTarget {
        var target = library.pointerTarget
        if !pointerAgentState.allowsPointerSettings {
            target.settings = .standard
        }
        return target
    }

    /// The agent is registered only while a profile has pointer settings of its own.
    private func updatePointerAgent() {
        let isNeeded = library.usesPointerSettings
        guard isNeeded != pointerAgentIsNeeded else { return }
        pointerAgentIsNeeded = isNeeded
        pointerAgentState = PointerAgent.state
        let previous = pointerAgentWork
        pointerAgentWork = Task {
            await previous?.value
            do {
                pointerAgentState = try await PointerAgent.update(isNeeded: isNeeded)
            } catch {
                pointerAgentState = PointerAgent.state
                log.error("Pointer agent: \(error.localizedDescription, privacy: .public)")
            }
            applyPointerTargetIfChanged()
        }
    }

    /// Returns `false` while the mouse's pointer is not in the HID event system.
    @discardableResult
    private func applyPointer(_ target: PointerTarget) -> Bool {
        do {
            switch try pointerTuner.apply(target) {
            case .applied:
                appliedPointer = target
                pointerError = nil
            case .mouseNotFound:
                appliedPointer = nil
                return false
            }
        } catch {
            appliedPointer = nil
            pointerError = error.localizedDescription
            log.error("Pointer: \(error.localizedDescription, privacy: .public)")
        }
        return true
    }

    /// The pointer appears in the HID event system a little after the mouse connects, and starts with
    /// macOS's settings.
    private func applyPointerOnceMouseAppears() {
        pointerSearch?.cancel()
        appliedPointer = nil
        pointerSearch = Task {
            for delay in [0, 250, 500, 1000, 2000, 4000] {
                try? await Task.sleep(for: .milliseconds(delay))
                if Task.isCancelled || applyPointer(pointerTargetToApply) {
                    return
                }
            }
        }
    }

    /// A saved file that could not be used may still hold presets, and the first save would replace it.
    private func keepUnusableSavedFile() {
        do {
            if let copy = try store.keepCopyOfSavedFile() {
                log.error("Could not use the saved presets; kept them as \(copy.lastPathComponent, privacy: .public)")
            }
        } catch {
            log.error("Could not use or copy the saved presets: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func connectionChanged() {
        isMouseConnected = connection.configurationChannel != nil
        if case .failed = writeState {
            writeState = .idle
        }
        if isMouseConnected {
            applyPointerOnceMouseAppears()
        } else {
            pointerSearch?.cancel()
            appliedPointer = nil
        }
        log.info("Mouse \(self.isMouseConnected ? "connected" : "disconnected", privacy: .public)")
    }

    private func persist() {
        do {
            try store.save(library)
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: any Error) {
        writeState = .failed(error.localizedDescription)
        log.error("\(error.localizedDescription, privacy: .public)")
    }
}
