import Foundation
import Testing
import ZelotesKit

@Suite struct PresetLibraryTests {
    @Test func startsWithOnePresetOfFactoryDefaultsInTheReserve() {
        let library = PresetLibrary()

        #expect(library.presets.map(\.name) == ["Default"])
        #expect(library.presets[0].table == .factoryDefault)
        #expect(library.reservePresets == library.presets)
        #expect(library.preset(in: .first) == nil)
        #expect(library.preset(in: .second) == nil)
    }

    @Test func addedPresetsGetDistinctNames() {
        var library = PresetLibrary()

        library.addPreset()
        library.addPreset()

        #expect(library.presets.map(\.name) == ["Default", "Preset 2", "Preset 3"])
    }

    @Test func aCopyKeepsTheMappingTheDPIAndTheSymbolAndSaysSoInItsName() throws {
        var library = PresetLibrary()
        let original = library.presets[0].id
        library.updatePreset(original) {
            $0.table[.thumbFront] = .media(.mute)
            $0.dpi[3] = 900
            $0.dpi.activeStage = 2
            $0.dpi.pollingRate = .hz125
            $0.symbol = "gamecontroller.fill"
        }

        let firstCopy = library.addPreset(copying: original)
        library.addPreset(copying: original)

        #expect(library.presets.map(\.name) == ["Default", "Default copy", "Default copy 2"])
        let copy = try #require(library.preset(firstCopy))
        #expect(copy.table[.thumbFront] == .media(.mute))
        #expect(copy.dpi == library.preset(original)?.dpi)
        #expect(copy.dpi[3] == 900)
        #expect(copy.symbol == "gamecontroller.fill")
    }

    @Test func aCopyKeepsTheStageNames() throws {
        var library = PresetLibrary()
        let original = library.presets[0].id
        library.updatePreset(original) {
            $0.stageNames[1] = "Precision"
            $0.stageNames[3] = "Gaming"
        }

        let copyID = library.addPreset(copying: original)

        let copy = try #require(library.preset(copyID))
        #expect(copy.stageNames == library.preset(original)?.stageNames)
        #expect(copy.stageNames.title(of: 3) == "Gaming")
    }

    @Test func aNewPresetStartsWithUnnamedStages() {
        var library = PresetLibrary()

        let added = library.addPreset()

        #expect(library.preset(added)?.stageNames == .unnamed)
    }

    @Test func renamingAStageLeavesAnUpToDateProfileUpToDate() {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .first)

        library.updatePreset(preset) { $0.stageNames[2] = "Desktop" }

        #expect(library.isUpToDate(.first))
        #expect(library.pendingUpdate(of: .first) == nil)
    }

    @Test func aNewPresetStartsWithFactoryDPI() {
        var library = PresetLibrary()

        let added = library.addPreset()

        #expect(library.preset(added)?.dpi == .factoryDefault)
        #expect(library.presets[0].dpi == .factoryDefault)
    }

    @Test func theLastPresetCannotBeRemoved() {
        var library = PresetLibrary()
        let only = library.presets[0].id
        let added = library.addPreset()

        library.removePreset(added)
        library.removePreset(only)

        #expect(library.presets.map(\.id) == [only])
    }

    @Test func aWrittenPresetLeavesTheReserveForItsProfile() {
        var library = PresetLibrary()
        let first = library.presets[0].id
        let second = library.addPreset()
        let third = library.addPreset()

        library.recordWrite(ofStored: second, to: .first)

        #expect(library.profile(holding: second) == .first)
        #expect(library.preset(in: .first)?.id == second)
        #expect(library.profile(holding: first) == nil)
        #expect(library.reservePresets.map(\.id) == [first, third])
    }

    @Test func writingAnotherPresetToAProfileReplacesTheOneThere() {
        var library = PresetLibrary()
        let replaced = library.presets[0].id
        let replacement = library.addPreset()
        library.recordWrite(ofStored: replaced, to: .second)

        library.recordWrite(ofStored: replacement, to: .second)

        #expect(library.preset(in: .second)?.id == replacement)
        #expect(library.profile(holding: replaced) == nil)
    }

    @Test func aProfileIsOutOfDateOnceItsPresetChanges() {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .first)
        #expect(library.isUpToDate(.first))

        library.updatePreset(preset) { $0.table[.dpiButton] = .disabled }
        #expect(!library.isUpToDate(.first))

        library.updatePreset(preset) { $0.table = .factoryDefault }
        #expect(library.isUpToDate(.first))

        library.updatePreset(preset) { $0.dpi[1] = 800 }
        #expect(!library.isUpToDate(.first))

        library.updatePreset(preset) { $0.dpi = .factoryDefault }
        #expect(library.isUpToDate(.first))
    }

    @Test func aProfileNothingWasWrittenToIsUpToDate() {
        let library = PresetLibrary()

        #expect(library.isUpToDate(.first))
        #expect(library.isUpToDate(.second))
        #expect(library.pendingUpdate(of: .first) == nil)
        #expect(library.pendingUpdate(of: .second) == nil)
    }

    @Test func nothingIsPendingWhileBothPartsMatchTheRecord() {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.updatePreset(preset) {
            $0.table[.thumbRear] = .media(.mute)
            $0.dpi[4] = 3000
        }

        library.recordWrite(ofStored: preset, to: .second)

        #expect(library.pendingUpdate(of: .second) == nil)
        #expect(library.isUpToDate(.second))
    }

    @Test func onlyTheButtonsArePendingWhenOnlyTheButtonsDiffer() throws {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .first)

        library.updatePreset(preset) { $0.table[.wheelPress] = .disabled }

        let stored = try #require(library.preset(preset))
        #expect(library.pendingUpdate(of: .first) == ProfileUpdate(buttons: stored.table))
    }

    @Test func onlyTheDPIIsPendingWhenOnlyTheDPIDiffers() throws {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .first)

        library.updatePreset(preset) { $0.dpi.pollingRate = .hz1000 }

        let stored = try #require(library.preset(preset))
        #expect(library.pendingUpdate(of: .first) == ProfileUpdate(dpi: stored.dpi, lighting: stored.lighting))
    }

    @Test func bothPartsArePendingWhenBothDiffer() throws {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .first)

        library.updatePreset(preset) {
            $0.table[.wheelPress] = .disabled
            $0.dpi[5] = 6000
        }

        let stored = try #require(library.preset(preset))
        #expect(
            library.pendingUpdate(of: .first)
                == ProfileUpdate(buttons: stored.table, dpi: stored.dpi, lighting: stored.lighting)
        )
    }

    @Test func aRecordWithoutDPIMakesTheDPIPending() throws {
        var library = PresetLibrary()
        library.recordWrite(ofStored: library.presets[0].id, to: .first)

        let recordedBeforeDPIExisted = try Self.dropRecordedDPI(of: library)

        #expect(recordedBeforeDPIExisted.written(to: .first)?.dpi == nil)
        #expect(
            recordedBeforeDPIExisted.pendingUpdate(of: .first)
                == ProfileUpdate(dpi: .factoryDefault, lighting: Preset.defaultLighting)
        )
        #expect(!recordedBeforeDPIExisted.isUpToDate(.first))
    }

    @Test func writingARecordRemembersTheButtonsAndTheDPIOfThePreset() throws {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.updatePreset(preset) {
            $0.table[.thumbFront] = .media(.mute)
            $0.dpi[2] = 1200
        }

        library.recordWrite(ofStored: preset, to: .second)

        let stored = try #require(library.preset(preset))
        let record = try #require(library.written(to: .second))
        #expect(record.presetID == preset)
        #expect(record.table == stored.table)
        #expect(record.dpi == stored.dpi)
    }

    @Test func recordingAStageSelectionKeepsAnUpToDateProfileUpToDate() throws {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .first)
        let before = try #require(library.written(to: .first))

        library.updatePreset(preset) { $0.dpi.activeStage = 3 }
        #expect(!library.isUpToDate(.first))
        library.recordStageSelection(3, in: .first)

        #expect(library.isUpToDate(.first))
        let after = try #require(library.written(to: .first))
        #expect(after.dpi?.activeStage == 3)
        #expect(after.presetID == before.presetID)
        #expect(after.table == before.table)
    }

    @Test func recordingAStageSelectionKeepsTheOtherDPIOfTheRecord() throws {
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.recordWrite(ofStored: preset, to: .second)

        library.updatePreset(preset) { $0.dpi[2] = 1200 }
        library.recordStageSelection(4, in: .second)

        let recorded = try #require(library.written(to: .second)?.dpi)
        #expect(recorded.activeStage == 4)
        #expect(recorded[2] == 2500)
    }

    @Test func recordingAStageSelectionLeavesARecordWithoutDPIWithout() throws {
        var library = PresetLibrary()
        library.recordWrite(ofStored: library.presets[0].id, to: .first)
        var recordedBeforeDPIExisted = try Self.dropRecordedDPI(of: library)

        recordedBeforeDPIExisted.recordStageSelection(3, in: .first)

        #expect(recordedBeforeDPIExisted.written(to: .first)?.dpi == nil)
        #expect(
            recordedBeforeDPIExisted.pendingUpdate(of: .first)
                == ProfileUpdate(dpi: .factoryDefault, lighting: Preset.defaultLighting)
        )
    }

    @Test func recordingAStageSelectionLeavesTheOtherProfileAlone() {
        var library = PresetLibrary()
        let first = library.presets[0].id
        let second = library.addPreset()
        library.recordWrite(ofStored: first, to: .first)
        library.recordWrite(ofStored: second, to: .second)
        let secondRecord = library.written(to: .second)

        library.recordStageSelection(5, in: .first)

        #expect(library.written(to: .first)?.dpi?.activeStage == 5)
        #expect(library.written(to: .second) == secondRecord)
    }

    @Test func recordingAStageSelectionForAnEmptyProfileChangesNothing() {
        var library = PresetLibrary()
        let untouched = library

        library.recordStageSelection(2, in: .first)

        #expect(library == untouched)
    }

    @Test func removingAWrittenPresetEmptiesItsProfileButKeepsTheRecord() {
        var library = PresetLibrary()
        let removed = library.addPreset()
        var written = ButtonTable.factoryDefault
        written[.joystickPress] = .disabled
        library.updatePreset(removed) { $0.table = written }
        library.recordWrite(ofStored: removed, to: .second)

        library.removePreset(removed)

        #expect(library.preset(in: .second) == nil)
        #expect(library.isUpToDate(.second))
        #expect(library.pendingUpdate(of: .second) == nil)
        #expect(library.written(to: .second)?.table == written)
    }

    @Test func clearingARecordReturnsItsPresetToTheReserveAndLeavesTheOtherProfile() {
        var library = PresetLibrary()
        let cleared = library.presets[0].id
        let kept = library.addPreset()
        library.recordWrite(ofStored: cleared, to: .first)
        library.recordWrite(ofStored: kept, to: .second)

        library.clearRecord(of: .first)

        #expect(library.written(to: .first) == nil)
        #expect(library.reservePresets.map(\.id) == [cleared])
        #expect(library.preset(in: .second)?.id == kept)
    }

    @Test func anUnnamedPresetShowsAPlaceholderNameAndItsCopySaysSo() {
        var library = PresetLibrary()
        let original = library.presets[0].id
        library.updatePreset(original) { $0.name = "" }

        let copy = library.addPreset(copying: original)

        #expect(library.preset(original)?.displayName == "Untitled")
        #expect(library.preset(copy)?.name == "Untitled copy")
    }

    @Test func decodingRejectsALibraryWithoutPresets() {
        let empty = Data(#"{"presets":[]}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PresetLibrary.self, from: empty)
        }
    }

    private static func dropRecordedDPI(of library: PresetLibrary) throws -> PresetLibrary {
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(library)) as? [String: Any]
        )
        var record = try #require(json["firstSlot"] as? [String: Any])
        record["dpi"] = nil
        json["firstSlot"] = record
        return try JSONDecoder().decode(PresetLibrary.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

private extension PresetLibrary {
    mutating func recordWrite(ofStored id: Preset.ID, to profile: MouseProfile) {
        recordWrite(of: preset(id)!, to: profile)
    }
}
