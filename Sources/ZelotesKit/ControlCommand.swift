/// An eight-byte command for the mouse's configuration interface.
struct ControlCommand: Equatable, Sendable {
    let bytes: [UInt8]

    /// Bytes the mouse expects as output reports after a prepare command. Until all have arrived it sends no
    /// movement or button reports and ignores the commit.
    static let dataPhaseLength = 128

    static let prepareButtonTableOpcode: UInt8 = 0x0D
    static let prepareDPITableOpcode: UInt8 = 0x0C

    static let beginTransaction = ControlCommand(opcode: 0x01, 0x88, 0x00)

    static func prepareButtonTable(profile: MouseProfile) -> ControlCommand {
        ControlCommand(opcode: prepareButtonTableOpcode, profile.rawValue, UInt8(dataPhaseLength))
    }

    static func prepareDPITable(profile: MouseProfile) -> ControlCommand {
        ControlCommand(opcode: prepareDPITableOpcode, profile.rawValue, UInt8(dataPhaseLength))
    }

    static func setPollingRate(_ rate: PollingRate, profile: MouseProfile) -> ControlCommand {
        ControlCommand(opcode: 0x03, profile.rawValue, rate.pollingInterval)
    }

    /// `stage` is one of `DPISettings.stages`.
    static func selectDPIStage(_ stage: Int, profile: MouseProfile) -> ControlCommand {
        ControlCommand(opcode: 0x04, profile.rawValue, UInt8(stage))
    }

    static func selectProfile(_ profile: MouseProfile) -> ControlCommand {
        ControlCommand(opcode: 0x02, profile.rawValue, 0x00)
    }

    /// Ends a transaction and makes `profile` the active one: `selectProfile` sent last.
    static func commit(profile: MouseProfile) -> ControlCommand {
        selectProfile(profile)
    }

    var opcode: UInt8 { bytes[0] }

    private init(opcode: UInt8, _ first: UInt8, _ second: UInt8) {
        let payload: [UInt8] = [opcode, first, second, 0, 0, 0, 0]
        bytes = payload + [Self.checksum(of: payload)]
    }

    // The firmware expects all eight bytes to add up to 0xFF.
    private static func checksum(of payload: [UInt8]) -> UInt8 {
        0xFF &- payload.reduce(0, &+)
    }
}
