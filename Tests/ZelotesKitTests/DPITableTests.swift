import Testing
@testable import ZelotesKit

@Suite struct DPITableTests {
    private static let measuredSensorCodes: [(dpi: Int, code: UInt8)] = [
        (200, 0x04), (300, 0x06), (400, 0x08), (600, 0x0D), (800, 0x12),
        (1000, 0x16), (1200, 0x1B), (1600, 0x24), (2000, 0x2E), (2300, 0x34),
        (2400, 0x37), (2600, 0x3B), (3000, 0x45), (3200, 0x49), (4800, 0x6F),
        (5000, 0x73), (6400, 0xC9), (6600, 0xCC), (7000, 0xD0), (10_000, 0xF3),
    ]

    @Test(arguments: measuredSensorCodes)
    func everyMeasuredPointEncodesToItsCapturedSensorCode(dpi: Int, code: UInt8) {
        #expect(DPITable.sensorCode(forDPI: dpi) == code)
    }

    @Test func halfTheDPIOfTheHighRangeIsTheLowRangeCodeBehindTheHighBit() {
        #expect(DPITable.sensorCode(forDPI: 3300 * 2) == 0x80 | 0x4C)
        #expect(DPITable.sensorCode(forDPI: 3500 * 2) == 0x80 | 0x50)
    }

    @Test func codesBetweenMeasuredPointsAreInterpolatedToTheNearestCode() {
        #expect(DPITable.sensorCode(forDPI: 1500) == 0x22)
        #expect(DPITable.sensorCode(forDPI: 2500) == 0x39)
        #expect(DPITable.sensorCode(forDPI: 4000) == 0x5C)
        #expect(DPITable.sensorCode(forDPI: 1100) == 0x19)
    }

    @Test func codesRiseWithDPIWithinEachRangeAndTheHighBitMarksTheUpperOne() {
        let steps = Array(stride(from: 200, through: 10_000, by: 100))
        let low = steps.filter { $0 <= 5000 }.map(DPITable.sensorCode(forDPI:))
        let high = steps.filter { $0 > 5000 }.map(DPITable.sensorCode(forDPI:))

        #expect(low == low.sorted())
        #expect(high == high.sorted())
        #expect(low.allSatisfy { $0 < 0x80 })
        #expect(high.allSatisfy { $0 >= 0x80 })
    }

    @Test func factoryDPIEncodesToTheFactoryTableOfEachProfile() {
        #expect(DPITable(.factoryDefault, for: .first).wireBytes == CapturedDPITables.firstFactory)
        #expect(DPITable(.factoryDefault, for: .second).wireBytes == CapturedDPITables.secondFactory)
    }

    @Test func theCapturedEditsOfProfileOneEncodeToTheCapturedTables() {
        var settings = DPISettings.factoryDefault

        settings[1] = 1000
        #expect(DPITable(settings, for: .first).wireBytes == CapturedDPITables.firstStageOneSetTo1000)
        settings[3] = 3000
        #expect(DPITable(settings, for: .first).wireBytes == CapturedDPITables.thenStageThreeSetTo3000)
        settings[4] = 5000
        #expect(DPITable(settings, for: .first).wireBytes == CapturedDPITables.thenStageFourSetTo5000)
        settings[5] = 7000
        #expect(DPITable(settings, for: .first).wireBytes == CapturedDPITables.thenStageFiveSetTo7000)
    }

    @Test func eachStageIsPatchedIntoItsXAndYOffsetsAndNothingElseMoves() {
        var settings = DPISettings.factoryDefault
        for (stage, dpi) in zip(DPISettings.stages, [200, 400, 800, 1600, 3200]) {
            settings[stage] = dpi
        }
        let codes: [UInt8] = [0x04, 0x08, 0x12, 0x24, 0x49]

        let factoryTables: [(MouseProfile, [UInt8])] = [
            (.first, CapturedDPITables.firstFactory),
            (.second, CapturedDPITables.secondFactory),
        ]
        for (profile, factory) in factoryTables {
            var expected = factory
            expected.replaceSubrange(20..<25, with: codes)
            expected.replaceSubrange(28..<33, with: codes)
            #expect(DPITable(settings, for: profile).wireBytes == expected)
        }
    }

    @Test func theActiveStageAndThePollingRateAreNotPartOfTheTable() {
        var settings = DPISettings.factoryDefault
        settings.activeStage = 4
        settings.pollingRate = .hz1000

        #expect(DPITable(settings, for: .second).wireBytes == CapturedDPITables.secondFactory)
    }

    @Test func thePrimerIsFFFFFollowedByZerosToTheLengthOfAReport() {
        #expect(DPITable.primer == [0xFF, 0xFF] + [UInt8](repeating: 0, count: 62))
    }
}
