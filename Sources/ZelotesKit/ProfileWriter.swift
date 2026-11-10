@MainActor
public protocol ReportTransport {
    func sendFeatureReport(_ bytes: [UInt8]) throws
    func sendOutputReport(_ bytes: [UInt8]) throws
    func readFeatureReport() throws -> [UInt8]
}

/// What the mouse's feature report says about the transaction in progress: byte 0 is the last accepted opcode,
/// byte 2 the number of data bytes still expected.
struct TransactionStatus: Equatable {
    let lastOpcode: UInt8
    let pendingDataBytes: Int
}

extension TransactionStatus {
    init(report: [UInt8]) {
        lastOpcode = report.first ?? 0
        pendingDataBytes = report.count > 2 ? Int(report[2]) : 0
    }
}

@MainActor
public struct ProfileWriter {
    public typealias Pause = @MainActor (Duration) async throws -> Void

    static let settleAfterCommand = Duration.milliseconds(20)
    static let settleAfterData = Duration.milliseconds(40)

    static let buttonDataPadding = [UInt8](
        repeating: 0,
        count: ControlCommand.dataPhaseLength - ButtonTable.wireLength
    )

    private let transport: any ReportTransport
    private let pause: Pause

    public init(
        transport: any ReportTransport,
        pause: @escaping Pause = { try await Task.sleep(for: $0) }
    ) {
        self.transport = transport
        self.pause = pause
    }

    /// Writes the parts of `update` to `profile` in one transaction and makes it the active profile.
    /// The DPI settings and the lighting go first, as in the vendor software.
    /// Throws `MouseAccessError.writeNotConfirmed` as soon as the mouse's status disagrees with a step.
    public func write(_ update: ProfileUpdate, to profile: MouseProfile) async throws {
        try await send(.beginTransaction)
        if let dpi = update.dpi {
            try await writeDPI(dpi, lighting: update.lighting ?? .factory(for: profile), to: profile)
        }
        if let buttons = update.buttons {
            try await writeButtons(buttons, to: profile)
        }
        try await send(.commit(profile: profile))
    }

    /// Makes `profile` the active one without changing what it holds.
    public func select(_ profile: MouseProfile) async throws {
        try await send(.beginTransaction)
        try await send(.commit(profile: profile))
    }

    /// Switches the mouse to `stage` of `profile` and makes that profile active, without changing any table.
    public func selectStage(_ stage: Int, of profile: MouseProfile) async throws {
        try await send(.beginTransaction)
        try await send(.selectProfile(profile))
        try await send(.selectDPIStage(stage, profile: profile))
        try await send(.commit(profile: profile))
    }

    private func writeDPI(_ dpi: DPISettings, lighting: Lighting, to profile: MouseProfile) async throws {
        // The vendor software selects the profile first: the rate and stage commands may act on the active one.
        try await send(.selectProfile(profile))
        try await send(.setPollingRate(dpi.pollingRate, profile: profile))
        try await send(.selectDPIStage(dpi.activeStage, profile: profile))
        try await send(.prepareDPITable(profile: profile), leavingPending: ControlCommand.dataPhaseLength)
        try await sendDataPhase(
            [DPITable.primer, DPITable(dpi, lighting: lighting).wireBytes],
            afterOpcode: ControlCommand.prepareDPITableOpcode
        )
    }

    private func writeButtons(_ buttons: ButtonTable, to profile: MouseProfile) async throws {
        try await send(.prepareButtonTable(profile: profile), leavingPending: ControlCommand.dataPhaseLength)
        try await sendDataPhase(
            [buttons.wireBytes, Self.buttonDataPadding],
            afterOpcode: ControlCommand.prepareButtonTableOpcode
        )
    }

    private func send(_ command: ControlCommand, leavingPending pendingDataBytes: Int = 0) async throws {
        try transport.sendFeatureReport(command.bytes)
        try await pause(Self.settleAfterCommand)
        try confirm(TransactionStatus(lastOpcode: command.opcode, pendingDataBytes: pendingDataBytes))
    }

    private func sendDataPhase(_ reports: [[UInt8]], afterOpcode opcode: UInt8) async throws {
        var pendingDataBytes = ControlCommand.dataPhaseLength
        for report in reports {
            pendingDataBytes -= report.count
            try transport.sendOutputReport(report)
            try await pause(Self.settleAfterData)
            try confirm(TransactionStatus(lastOpcode: opcode, pendingDataBytes: pendingDataBytes))
        }
    }

    private func confirm(_ expected: TransactionStatus) throws {
        let report = try transport.readFeatureReport()
        guard TransactionStatus(report: report) == expected else {
            throw MouseAccessError.writeNotConfirmed(status: report)
        }
    }
}
