import Foundation
import Testing
import ZelotesKit

@Suite struct DPIStageNamesTests {
    @Test func aStageWithoutANameIsTitledByItsNumber() {
        let names = DPIStageNames.unnamed
        let titles = DPISettings.stages.map { names.title(of: $0) }

        #expect(titles == ["Stage 1", "Stage 2", "Stage 3", "Stage 4", "Stage 5"])
        #expect(DPISettings.stages.map { names[$0] } == ["", "", "", "", ""])
    }

    @Test func aNamedStageIsTitledByItsNameAndTheOthersKeepTheirNumbers() {
        var names = DPIStageNames.unnamed

        names[3] = "Gaming"

        #expect(names.title(of: 3) == "Gaming")
        #expect(names[3] == "Gaming")
        #expect(names.title(of: 2) == "Stage 2")
        #expect(names.title(of: 4) == "Stage 4")
    }

    @Test func aNameIsTrimmedWhenSet() {
        var names = DPIStageNames.unnamed

        names[2] = "  Gaming \n"

        #expect(names[2] == "Gaming")
    }

    @Test func aNameOfOnlyWhitespaceLeavesTheStageUnnamed() {
        var names = DPIStageNames.unnamed
        names[5] = "Desktop"

        names[5] = "   "

        #expect(names[5] == "")
        #expect(names.title(of: 5) == "Stage 5")
        #expect(names == .unnamed)
    }

    @Test func namesAreStoredAsAPlainArrayOfFiveStrings() throws {
        var names = DPIStageNames.unnamed
        names[1] = "Precision"
        names[3] = "Gaming"

        let json = try #require(String(data: JSONEncoder().encode(names), encoding: .utf8))

        #expect(json == #"["Precision","","Gaming","",""]"#)
    }

    @Test func namesSurviveARoundTrip() throws {
        var names = DPIStageNames.unnamed
        names[2] = "Desktop"
        names[4] = "Sniping"

        let decoded = try JSONDecoder().decode(DPIStageNames.self, from: JSONEncoder().encode(names))

        #expect(decoded == names)
    }

    @Test(arguments: [#"["a","b","c","d"]"#, #"["a","b","c","d","e","f"]"#, "[]"])
    func decodingRejectsAnyOtherCountThanFive(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(DPIStageNames.self, from: Data(json.utf8))
        }
    }
}
