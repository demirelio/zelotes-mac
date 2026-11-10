import Foundation
import Testing
import ZelotesKit

@Suite struct DPISettingsTests {
    @Test func factoryDefaultReadsTheFactoryStageCodesBackAsDPI() {
        let settings = DPISettings.factoryDefault

        #expect(DPISettings.stages.map { settings[$0] } == [1500, 2500, 4000, 7000, 10_000])
        #expect(settings.activeStage == 1)
        #expect(settings.pollingRate == .hz500)
    }

    @Test(arguments: [(1549, 1500), (1550, 1600), (50, 200), (150, 200), (250, 300), (12_000, 10_000), (-300, 200)])
    func aStageRoundsToTheNearestStepAndStaysInRange(typed: Int, stored: Int) {
        var settings = DPISettings.factoryDefault

        settings[2] = typed

        #expect(settings[2] == stored)
        #expect(DPISettings.normalized(typed) == stored)
    }

    @Test func settingOneStageLeavesTheOthers() {
        var settings = DPISettings.factoryDefault

        settings[3] = 800

        #expect(DPISettings.stages.map { settings[$0] } == [1500, 2500, 800, 7000, 10_000])
    }

    @Test func theActiveStageStaysWithinTheStages() {
        var settings = DPISettings.factoryDefault

        settings.activeStage = 9
        #expect(settings.activeStage == 5)
        settings.activeStage = 0
        #expect(settings.activeStage == 1)
    }

    @Test func aRoundTripKeepsEverything() throws {
        var settings = DPISettings.factoryDefault
        settings[1] = 400
        settings[5] = 3200
        settings.activeStage = 3
        settings.pollingRate = .hz1000

        let decoded = try JSONDecoder().decode(DPISettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
    }

    @Test func thePollingRateIsStoredInHertzUnderTheKeySavedFilesUse() throws {
        var settings = DPISettings.factoryDefault
        settings.pollingRate = .hz250

        let json = try #require(String(data: JSONEncoder().encode(settings), encoding: .utf8))

        #expect(json.contains(#""reportRate":250"#))
    }

    @Test func theActiveStageIsStoredUnderTheKeySavedFilesUse() throws {
        let saved = Data(#"{"dpiByStage":[1500,2500,4000,7000,10000],"startingStage":4,"reportRate":500}"#.utf8)

        let decoded = try JSONDecoder().decode(DPISettings.self, from: saved)

        #expect(decoded.activeStage == 4)
        let json = try #require(String(data: JSONEncoder().encode(decoded), encoding: .utf8))
        #expect(json.contains(#""startingStage":4"#))
        #expect(!json.contains("activeStage"))
    }

    @Test(arguments: [
        "[1500,2500,4000,7000]",
        "[1500,2500,4000,7000,10000,10000]",
        "[1500,2500,4000,7000,10100]",
        "[150,2500,4000,7000,10000]",
        "[1500,2500,0,7000,10000]",
    ])
    func decodingRejectsWrongStages(stages: String) {
        let json = Data(#"{"dpiByStage":\#(stages),"startingStage":1,"reportRate":500}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DPISettings.self, from: json)
        }
    }

    @Test(arguments: [0, 6])
    func decodingRejectsAnActiveStageOutsideTheStages(stage: Int) {
        let json = Data(#"{"dpiByStage":[1500,2500,4000,7000,10000],"startingStage":\#(stage),"reportRate":500}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DPISettings.self, from: json)
        }
    }

    @Test func decodingRejectsAPollingRateTheMouseDoesNotHave() {
        let json = Data(#"{"dpiByStage":[1500,2500,4000,7000,10000],"startingStage":1,"reportRate":333}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DPISettings.self, from: json)
        }
    }
}
