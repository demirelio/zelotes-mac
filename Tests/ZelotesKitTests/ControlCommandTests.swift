import Testing
@testable import ZelotesKit

@Suite struct ControlCommandTests {
    private static let pollingRatePackets: [(PollingRate, UInt8, UInt8)] = [
        (.hz1000, 1, 0xFA), (.hz500, 2, 0xF9), (.hz250, 4, 0xF7), (.hz125, 8, 0xF3),
    ]

    @Test func beginTransactionMatchesTheCapturedPacket() {
        #expect(ControlCommand.beginTransaction.bytes == [0x01, 0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x76])
    }

    @Test func prepareButtonTableCarriesTheProfileNumber() {
        #expect(
            ControlCommand.prepareButtonTable(profile: .second).bytes
                == [0x0D, 0x02, 0x80, 0x00, 0x00, 0x00, 0x00, 0x70]
        )
    }

    @Test func commitMatchesTheCapturedPacketOfEachProfile() {
        #expect(ControlCommand.commit(profile: .first).bytes == [0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC])
        #expect(ControlCommand.commit(profile: .second).bytes == [0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFB])
    }

    @Test func setPollingRateMatchesTheCapturedPacket() {
        #expect(
            ControlCommand.setPollingRate(.hz500, profile: .second).bytes
                == [0x03, 0x02, 0x02, 0x00, 0x00, 0x00, 0x00, 0xF8]
        )
    }

    @Test(arguments: pollingRatePackets)
    func setPollingRateSendsTheMillisecondsBetweenReports(rate: PollingRate, milliseconds: UInt8, checksum: UInt8) {
        #expect(
            ControlCommand.setPollingRate(rate, profile: .first).bytes
                == [0x03, 0x01, milliseconds, 0x00, 0x00, 0x00, 0x00, checksum]
        )
    }

    @Test func selectDPIStageMatchesTheCapturedPackets() {
        #expect(
            ControlCommand.selectDPIStage(1, profile: .second).bytes
                == [0x04, 0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0xF8]
        )
        #expect(
            ControlCommand.selectDPIStage(2, profile: .first).bytes
                == [0x04, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0xF8]
        )
    }

    @Test func prepareDPITableMatchesTheCapturedPacketOfEachProfile() {
        #expect(
            ControlCommand.prepareDPITable(profile: .first).bytes
                == [0x0C, 0x01, 0x80, 0x00, 0x00, 0x00, 0x00, 0x72]
        )
        #expect(
            ControlCommand.prepareDPITable(profile: .second).bytes
                == [0x0C, 0x02, 0x80, 0x00, 0x00, 0x00, 0x00, 0x71]
        )
    }
}
