import Testing
@testable import ZelotesKit

@MainActor
@Suite struct ProfileWriterTests {
    @Test func writesTheButtonTableAndItsPaddingInsideOneTransaction() async throws {
        let mouse = FakeMouse()

        try await mouse.writer.write(ProfileUpdate(buttons: .factoryDefault), to: .second)

        #expect(mouse.events == [
            .feature(ControlCommand.beginTransaction.bytes),
            .pause(.milliseconds(20)),
            .feature(ControlCommand.prepareButtonTable(profile: .second).bytes),
            .pause(.milliseconds(20)),
            .output(ButtonTable.factoryDefault.wireBytes),
            .pause(.milliseconds(40)),
            .output([UInt8](repeating: 0, count: 64)),
            .pause(.milliseconds(40)),
            .feature(ControlCommand.commit(profile: .second).bytes),
            .pause(.milliseconds(20)),
        ])
    }

    @Test func writesTheDPIPartInTheOrderOfTheVendorSoftware() async throws {
        let mouse = FakeMouse()

        try await mouse.writer.write(ProfileUpdate(dpi: .factoryDefault), to: .second)

        #expect(mouse.events == [
            .feature([0x01, 0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x76]),
            .pause(.milliseconds(20)),
            .feature([0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFB]),
            .pause(.milliseconds(20)),
            .feature([0x03, 0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0xF8]),
            .pause(.milliseconds(20)),
            .feature([0x04, 0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0xF8]),
            .pause(.milliseconds(20)),
            .feature([0x0C, 0x02, 0x80, 0x00, 0x00, 0x00, 0x00, 0x71]),
            .pause(.milliseconds(20)),
            .output([0xFF, 0xFF] + [UInt8](repeating: 0, count: 62)),
            .pause(.milliseconds(40)),
            .output(CapturedDPITables.secondFactory),
            .pause(.milliseconds(40)),
            .feature([0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFB]),
            .pause(.milliseconds(20)),
        ])
    }

    @Test func theDPIPartCarriesThePollingRateAndTheActiveStage() async throws {
        let mouse = FakeMouse()
        var dpi = DPISettings.factoryDefault
        dpi.pollingRate = .hz1000
        dpi.activeStage = 3

        try await mouse.writer.write(ProfileUpdate(dpi: dpi), to: .first)

        #expect(mouse.features.contains([0x03, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0xFA]))
        #expect(mouse.features.contains([0x04, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00, 0xF7]))
    }

    @Test func bothPartsShareOneTransactionAndOneCommit() async throws {
        let mouse = FakeMouse()

        try await mouse.writer.write(ProfileUpdate(buttons: .factoryDefault, dpi: .factoryDefault), to: .first)

        #expect(mouse.events == [
            .feature(ControlCommand.beginTransaction.bytes),
            .pause(.milliseconds(20)),
            .feature(ControlCommand.selectProfile(.first).bytes),
            .pause(.milliseconds(20)),
            .feature(ControlCommand.setPollingRate(.hz500, profile: .first).bytes),
            .pause(.milliseconds(20)),
            .feature(ControlCommand.selectDPIStage(1, profile: .first).bytes),
            .pause(.milliseconds(20)),
            .feature(ControlCommand.prepareDPITable(profile: .first).bytes),
            .pause(.milliseconds(20)),
            .output(DPITable.primer),
            .pause(.milliseconds(40)),
            .output(CapturedDPITables.firstFactory),
            .pause(.milliseconds(40)),
            .feature(ControlCommand.prepareButtonTable(profile: .first).bytes),
            .pause(.milliseconds(20)),
            .output(ButtonTable.factoryDefault.wireBytes),
            .pause(.milliseconds(40)),
            .output([UInt8](repeating: 0, count: 64)),
            .pause(.milliseconds(40)),
            .feature(ControlCommand.commit(profile: .first).bytes),
            .pause(.milliseconds(20)),
        ])
    }

    @Test func anEmptyUpdateOnlyCommitsLikeSelecting() async throws {
        let mouse = FakeMouse()

        try await mouse.writer.write(ProfileUpdate(), to: .second)

        #expect(mouse.features == [
            ControlCommand.beginTransaction.bytes,
            ControlCommand.commit(profile: .second).bytes,
        ])
    }

    @Test(arguments: [
        ProfileUpdate(buttons: .factoryDefault),
        ProfileUpdate(dpi: .factoryDefault),
        ProfileUpdate(buttons: .factoryDefault, dpi: .factoryDefault),
    ])
    func sendsExactlyAsManyDataBytesAsEachPrepareCommandAnnounces(update: ProfileUpdate) async throws {
        let mouse = FakeMouse()

        try await mouse.writer.write(update, to: .first)

        let prepares = mouse.dataPhases
        #expect(prepares.count == (update.buttons == nil ? 0 : 1) + (update.dpi == nil ? 0 : 1))
        for phase in prepares {
            #expect(phase.sent == phase.announced)
        }
    }

    @Test func stopsBeforeCommittingWhenTheMouseStillExpectsButtonData() async {
        let mouse = FakeMouse()
        mouse.outputReportsAccepted = 0

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [0x0D, 0x01, 0x80, 0, 0, 0, 0, 0])) {
            try await mouse.writer.write(ProfileUpdate(buttons: .factoryDefault), to: .first)
        }

        #expect(!mouse.features.contains(ControlCommand.commit(profile: .first).bytes))
    }

    @Test func stopsBeforeCommittingWhenTheMouseStillExpectsDPIData() async {
        let mouse = FakeMouse()
        mouse.outputReportsAccepted = 0

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [0x0C, 0x01, 0x80, 0, 0, 0, 0, 0])) {
            try await mouse.writer.write(ProfileUpdate(dpi: .factoryDefault), to: .first)
        }

        #expect(mouse.features.last == ControlCommand.prepareDPITable(profile: .first).bytes)
    }

    @Test func stopsBeforeCommittingWhenTheMouseStallsAfterThePrimer() async {
        let mouse = FakeMouse()
        mouse.outputReportsAccepted = 1

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [0x0C, 0x01, 0x40, 0, 0, 0, 0, 0])) {
            try await mouse.writer.write(ProfileUpdate(buttons: .factoryDefault, dpi: .factoryDefault), to: .first)
        }

        #expect(mouse.features.last == ControlCommand.prepareDPITable(profile: .first).bytes)
    }

    @Test func stopsAtTheFirstCommandTheMouseDoesNotEcho() async {
        let mouse = FakeMouse()
        mouse.ignoresCommands = true

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [0, 0, 0, 0, 0, 0, 0, 0])) {
            try await mouse.writer.write(ProfileUpdate(buttons: .factoryDefault, dpi: .factoryDefault), to: .first)
        }

        #expect(mouse.events == [.feature(ControlCommand.beginTransaction.bytes), .pause(.milliseconds(20))])
    }

    @Test func aShortStatusReportDoesNotConfirmAStep() async {
        let mouse = FakeMouse()
        mouse.statusReportLength = 0

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [])) {
            try await mouse.writer.write(ProfileUpdate(buttons: .factoryDefault), to: .first)
        }
    }

    @Test func selectingAProfileCommitsAnEmptyTransaction() async throws {
        let mouse = FakeMouse()

        try await mouse.writer.select(.second)

        #expect(mouse.events == [
            .feature(ControlCommand.beginTransaction.bytes),
            .pause(.milliseconds(20)),
            .feature(ControlCommand.commit(profile: .second).bytes),
            .pause(.milliseconds(20)),
        ])
    }

    @Test func selectingStopsAtTheFirstCommandTheMouseDoesNotEcho() async {
        let mouse = FakeMouse()
        mouse.ignoresCommands = true

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [0, 0, 0, 0, 0, 0, 0, 0])) {
            try await mouse.writer.select(.first)
        }

        #expect(mouse.events == [.feature(ControlCommand.beginTransaction.bytes), .pause(.milliseconds(20))])
    }

    @Test func selectingAStageSendsOnlyTheStageCommandInsideOneTransaction() async throws {
        let mouse = FakeMouse()

        try await mouse.writer.selectStage(3, of: .first)

        #expect(mouse.events == [
            .feature([0x01, 0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x76]),
            .pause(.milliseconds(20)),
            .feature([0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC]),
            .pause(.milliseconds(20)),
            .feature([0x04, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00, 0xF7]),
            .pause(.milliseconds(20)),
            .feature([0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC]),
            .pause(.milliseconds(20)),
        ])
    }

    @Test func selectingAStageStopsAtTheFirstCommandTheMouseDoesNotEcho() async {
        let mouse = FakeMouse()
        mouse.ignoresCommands = true

        await #expect(throws: MouseAccessError.writeNotConfirmed(status: [0, 0, 0, 0, 0, 0, 0, 0])) {
            try await mouse.writer.selectStage(3, of: .first)
        }

        #expect(mouse.events == [.feature(ControlCommand.beginTransaction.bytes), .pause(.milliseconds(20))])
    }
}

/// Answers status reads the way the real mouse was observed to: last opcode, its profile, data bytes still expected.
@MainActor
private final class FakeMouse: ReportTransport {
    enum Event: Equatable {
        case feature([UInt8])
        case output([UInt8])
        case pause(Duration)
    }

    struct DataPhase {
        let announced: Int
        var sent = 0
    }

    private(set) var events: [Event] = []
    var outputReportsAccepted = Int.max
    var ignoresCommands = false
    var statusReportLength = 8

    private var status = [UInt8](repeating: 0, count: 8)
    private var outputReportsReceived = 0

    var features: [[UInt8]] {
        events.compactMap { if case .feature(let bytes) = $0 { bytes } else { nil } }
    }

    var dataPhases: [DataPhase] {
        var phases: [DataPhase] = []
        for event in events {
            switch event {
            case .feature(let bytes) where Self.isPrepare(bytes):
                phases.append(DataPhase(announced: Int(bytes[2])))
            case .output(let bytes):
                phases[phases.count - 1].sent += bytes.count
            default:
                break
            }
        }
        return phases
    }

    var writer: ProfileWriter {
        ProfileWriter(transport: self) { [self] in events.append(.pause($0)) }
    }

    func sendFeatureReport(_ bytes: [UInt8]) throws {
        events.append(.feature(bytes))
        guard !ignoresCommands else { return }
        let isBegin = bytes[0] == ControlCommand.beginTransaction.opcode
        status = [bytes[0], isBegin ? 0 : bytes[1], Self.isPrepare(bytes) ? bytes[2] : 0, 0, 0, 0, 0, 0]
    }

    func sendOutputReport(_ bytes: [UInt8]) throws {
        events.append(.output(bytes))
        outputReportsReceived += 1
        guard outputReportsReceived <= outputReportsAccepted else { return }
        status[2] -= UInt8(min(bytes.count, Int(status[2])))
    }

    func readFeatureReport() throws -> [UInt8] {
        Array(status.prefix(statusReportLength))
    }

    private static func isPrepare(_ command: [UInt8]) -> Bool {
        command[0] == ControlCommand.prepareButtonTableOpcode || command[0] == ControlCommand.prepareDPITableOpcode
    }
}
