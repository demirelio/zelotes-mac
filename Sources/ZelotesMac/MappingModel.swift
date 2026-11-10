import Foundation
import Observation
import ZelotesKit

@MainActor
@Observable
final class MappingModel {
    /// Whether the selected preset's pointer settings are the ones macOS uses now.
    enum PointerStatus: Equatable {
        case inUse
        case inReserve
        case profileNotActive(MouseProfile)
        case mouseNotConnected
        case refused(String)
    }

    /// An action waiting for the user's confirmation, because it cannot be undone or would leave the mouse
    /// without a Left Click.
    enum Confirmation: Equatable {
        case deletePreset(Preset)
        case assignWithoutLeftClick(Preset, MouseProfile)
    }

    /// How the saved version of the selected preset relates to the mouse.
    enum MouseState: Equatable {
        case inReserve
        case onMouse(MouseProfile)
        case changesPending(MouseProfile)
        case heldWithoutLeftClick(MouseProfile)

        var isHeldWithoutLeftClick: Bool {
            if case .heldWithoutLeftClick = self { true } else { false }
        }
    }

    /// Something the user asked for that may leave the preset being edited.
    enum Intent: Equatable {
        case show(Preset.ID)
        case showMacros
        case addPreset
        case duplicate(Preset.ID)
        case rename(Preset.ID)
        case reset(Preset.ID)
        case assign(Preset.ID, MouseProfile)
    }

    private(set) var selectedPresetID: Preset.ID {
        didSet {
            isRenamingPreset = false
            draft = nil
        }
    }
    var isRenamingPreset = false
    var presetPage = PresetPage.buttons
    var pendingConfirmation: Confirmation?
    /// Set while the user decides whether to save before `Intent` is carried out.
    var intentAwaitingSaveDecision: Intent?
    private(set) var isShowingMacros = false
    /// The selected preset's editable parts while they have edits that are not saved.
    private var draft: Draft?

    private struct Draft: Equatable {
        var table: ButtonTable
        var dpi: DPISettings
        var lighting: Lighting

        init(of preset: Preset) {
            table = preset.table
            dpi = preset.dpi
            lighting = preset.lighting
        }
    }

    @ObservationIgnored private let sync: MouseSync

    init(store: MappingStore = MappingStore(fileURL: MappingStore.standardFileURL), isPreview: Bool = false) {
        let sync = MouseSync(store: store, isPreview: isPreview)
        self.sync = sync
        selectedPresetID = (sync.library.preset(in: .first) ?? sync.library.presets[0]).id
    }

    var isMouseConnected: Bool {
        sync.isMouseConnected
    }

    /// The profile this app last made active on the mouse.
    var activeProfile: MouseProfile? {
        library.activeProfile
    }

    var canMakeProfileActive: Bool {
        isMouseConnected && writeState != .writing
    }

    var writeState: MouseSync.WriteState {
        sync.writeState
    }

    var reservePresets: [Preset] {
        library.reservePresets
    }

    var canDeletePresets: Bool {
        library.presets.count > 1
    }

    var presetName: String {
        get { selectedPreset.name }
        set { updateSelectedPreset { $0.name = newValue } }
    }

    var presetDisplayName: String {
        selectedPreset.displayName
    }

    var presetSymbol: String {
        get { selectedPreset.symbol }
        set { updateSelectedPreset { $0.symbol = newValue } }
    }

    var table: ButtonTable {
        get { draft?.table ?? selectedPreset.table }
        set { edit { $0.table = newValue } }
    }

    var dpi: DPISettings {
        get { draft?.dpi ?? selectedPreset.dpi }
        set { edit { $0.dpi = newValue } }
    }

    var lighting: Lighting {
        get { draft?.lighting ?? selectedPreset.lighting }
        set { edit { $0.lighting = newValue } }
    }

    var stageNames: DPIStageNames {
        get { selectedPreset.stageNames }
        set { updateSelectedPreset { $0.stageNames = newValue } }
    }

    /// Stored and applied at once, like a rename: the settings stay on the Mac and never make a profile out of date.
    var pointer: PointerSettings {
        get { selectedPreset.pointer }
        set { updateSelectedPreset { $0.pointer = newValue } }
    }

    var pointerStatus: PointerStatus {
        guard let profile = library.profile(holding: selectedPresetID) else { return .inReserve }
        guard profile == library.profileInUse else { return .profileNotActive(profile) }
        guard isMouseConnected else { return .mouseNotConnected }
        if let reason = sync.pointerError {
            return .refused(reason)
        }
        return .inUse
    }

    var pointerAgentState: PointerAgent.State {
        sync.pointerAgentState
    }

    func refreshPointerAgentState() {
        sync.refreshPointerAgentState()
    }

    var hasDPIStageButton: Bool {
        MouseButton.allCases.contains { table[$0].kind == .dpi }
    }

    var hasUnsavedChanges: Bool {
        draft != nil
    }

    var mouseState: MouseState {
        guard let profile = library.profile(holding: selectedPresetID) else { return .inReserve }
        guard let pending = library.pendingUpdate(of: profile) else { return .onMouse(profile) }
        return pending.buttons?.hasLeftClick == false ? .heldWithoutLeftClick(profile) : .changesPending(profile)
    }

    var canUpdateMouse: Bool {
        guard isMouseConnected, writeState != .writing, !isShowingMacros else { return false }
        switch mouseState {
        case .changesPending, .heldWithoutLeftClick: return true
        case .inReserve, .onMouse: return false
        }
    }

    func preset(in profile: MouseProfile) -> Preset? {
        library.preset(in: profile)
    }

    func profile(holding presetID: Preset.ID) -> MouseProfile? {
        library.profile(holding: presetID)
    }

    func isUpToDate(_ profile: MouseProfile) -> Bool {
        library.isUpToDate(profile)
    }

    func showPreset(_ id: Preset.ID) {
        request(.show(id))
    }

    func showMacros() {
        request(.showMacros)
    }

    func addPreset() {
        request(.addPreset)
    }

    func duplicatePreset(_ id: Preset.ID) {
        request(.duplicate(id))
    }

    func renamePreset(_ id: Preset.ID) {
        request(.rename(id))
    }

    func resetPreset(_ id: Preset.ID) {
        request(.reset(id))
    }

    /// Puts a preset into a mouse profile, which writes it to the mouse. Asks first when the open preset
    /// has unsaved edits or the preset has no Left Click button.
    func requestAssign(_ presetID: Preset.ID, to profile: MouseProfile) {
        request(.assign(presetID, profile))
    }

    func requestDelete(_ id: Preset.ID) {
        guard canDeletePresets, let preset = library.preset(id) else { return }
        pendingConfirmation = .deletePreset(preset)
    }

    /// Takes a preset out of its mouse profile. The mouse keeps the mapping until another preset replaces it.
    func moveToReserve(_ presetID: Preset.ID) {
        guard let profile = library.profile(holding: presetID) else { return }
        sync.changeAndSave { $0.clearRecord(of: profile) }
    }

    /// Makes `profile` the active one on the mouse, after the writes asked for earlier.
    func makeActive(_ profile: MouseProfile) {
        sync.enqueue { await self.sync.makeActive(profile) }
    }

    /// Stores the stage in the preset at once, like a rename, and in the draft when there is one. When the preset
    /// sits in a profile, the mouse switches to the stage after the writes asked for earlier.
    func chooseActiveStage(_ stage: Int) {
        let presetID = selectedPresetID
        updateSelectedPreset { $0.dpi.activeStage = stage }
        edit { $0.dpi.activeStage = stage }
        guard library.profile(holding: presetID) != nil else { return }
        sync.enqueue {
            guard let profile = self.library.profile(holding: presetID) else { return }
            await self.sync.selectStage(stage, in: profile)
        }
    }

    /// Stores the edits and, when the preset sits in a profile, writes them to the mouse.
    func save() {
        guard let draft else { return }
        let presetID = selectedPresetID
        updateSelectedPreset {
            $0.table = draft.table
            $0.dpi = draft.dpi
            $0.lighting = draft.lighting
        }
        self.draft = nil
        if let profile = library.profile(holding: presetID) {
            sync.enqueue { await self.sync.update(profile, evenWithoutLeftClick: false) }
        }
    }

    func discardChanges() {
        draft = nil
    }

    /// Continues with `intent` once the user has chosen what happens to the unsaved edits.
    func resolve(_ intent: Intent, saving: Bool) {
        intentAwaitingSaveDecision = nil
        if saving {
            save()
        } else {
            discardChanges()
        }
        perform(intent)
    }

    /// Writes the saved preset to the mouse now, even without a Left Click button.
    func updateMouse() {
        guard let profile = library.profile(holding: selectedPresetID) else { return }
        sync.enqueue { await self.sync.update(profile, evenWithoutLeftClick: true) }
    }

    func carryOut(_ confirmation: Confirmation) {
        switch confirmation {
        case .deletePreset(let preset):
            sync.changeAndSave { $0.removePreset(preset.id) }
            if library.preset(selectedPresetID) == nil {
                selectedPresetID = library.presets[0].id
            }
        case .assignWithoutLeftClick(let preset, let profile):
            place(preset.id, in: profile)
        }
    }

    /// Returns once every write to the mouse that was asked for has finished.
    func waitForMouse() async {
        await sync.waitUntilIdle()
    }

    private var library: PresetLibrary {
        sync.library
    }

    private var selectedPreset: Preset {
        library.preset(selectedPresetID) ?? library.presets[0]
    }

    private func updateSelectedPreset(_ change: (inout Preset) -> Void) {
        let id = selectedPresetID
        sync.changeAndSave { $0.updatePreset(id, change) }
    }

    private func edit(_ change: (inout Draft) -> Void) {
        let saved = Draft(of: selectedPreset)
        var edited = draft ?? saved
        change(&edited)
        draft = edited == saved ? nil : edited
    }

    private func request(_ intent: Intent) {
        if hasUnsavedChanges, leavesEditedPreset(intent) {
            intentAwaitingSaveDecision = intent
        } else {
            perform(intent)
        }
    }

    private func leavesEditedPreset(_ intent: Intent) -> Bool {
        switch intent {
        case .show(let id), .rename(let id), .reset(let id): id != selectedPresetID
        case .showMacros, .addPreset, .duplicate, .assign: true
        }
    }

    private func perform(_ intent: Intent) {
        switch intent {
        case .show(let id):
            select(id)
        case .showMacros:
            isShowingMacros = true
        case .addPreset:
            select(sync.changeAndSave { $0.addPreset() })
            isRenamingPreset = true
        case .duplicate(let id):
            select(sync.changeAndSave { $0.addPreset(copying: id) })
        case .rename(let id):
            select(id)
            isRenamingPreset = true
        case .reset(let id):
            select(id)
            let factoryLighting = library.profile(holding: id).map(Lighting.factory) ?? Preset.defaultLighting
            edit {
                $0.table = .factoryDefault
                $0.dpi = .factoryDefault
                $0.lighting = factoryLighting
            }
        case .assign(let id, let profile):
            assign(id, to: profile)
        }
    }

    private func select(_ id: Preset.ID) {
        if id != selectedPresetID {
            selectedPresetID = id
        }
        isShowingMacros = false
    }

    private func assign(_ presetID: Preset.ID, to profile: MouseProfile) {
        guard let preset = library.preset(presetID), library.profile(holding: presetID) != profile else { return }
        if preset.table.hasLeftClick {
            place(presetID, in: profile)
        } else {
            pendingConfirmation = .assignWithoutLeftClick(preset, profile)
        }
    }

    /// Writes the preset into `profile` after the writes asked for earlier, then shows it unless other edits are open.
    private func place(_ presetID: Preset.ID, in profile: MouseProfile) {
        sync.enqueue {
            guard let preset = self.library.preset(presetID) else { return }
            await self.sync.place(preset, in: profile)
            if !self.hasUnsavedChanges {
                self.select(presetID)
            }
        }
    }
}
