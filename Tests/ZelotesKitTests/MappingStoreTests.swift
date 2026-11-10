import Foundation
import Testing
import ZelotesKit

@Suite final class MappingStoreTests {
    private let fileURL = FileManager.default.temporaryDirectory
        .appending(path: "ZelotesKitTests-\(UUID().uuidString)/mappings.json")

    deinit {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    @Test func aLibrarySurvivesARoundTrip() throws {
        let store = MappingStore(fileURL: fileURL)
        var library = PresetLibrary()
        let added = library.addPreset()
        library.updatePreset(added) { $0.table[.thumbRear] = .media(.mute) }
        library.recordWrite(of: library.preset(added)!, to: .second)

        try store.save(library)

        #expect(store.load() == library)
    }

    @Test func editedDPISurvivesARoundTripInThePresetAndInTheRecord() throws {
        let store = MappingStore(fileURL: fileURL)
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.updatePreset(preset) {
            $0.dpi[1] = 800
            $0.dpi[5] = 6400
            $0.dpi.activeStage = 4
            $0.dpi.pollingRate = .hz1000
        }
        library.recordWrite(of: library.preset(preset)!, to: .first)
        library.updatePreset(preset) { $0.dpi[2] = 1200 }

        try store.save(library)

        let loaded = try #require(store.load())
        #expect(loaded == library)
        #expect(loaded.preset(preset)?.dpi[2] == 1200)
        #expect(loaded.preset(preset)?.dpi.pollingRate == .hz1000)
        #expect(loaded.written(to: .first)?.dpi?[2] == 2500)
        #expect(loaded.written(to: .first)?.dpi?.activeStage == 4)
    }

    @Test func stageNamesSurviveARoundTrip() throws {
        let store = MappingStore(fileURL: fileURL)
        var library = PresetLibrary()
        let preset = library.presets[0].id
        library.updatePreset(preset) {
            $0.stageNames[1] = "Precision"
            $0.stageNames[3] = "Gaming"
        }

        try store.save(library)

        let loaded = try #require(store.load())
        #expect(loaded == library)
        #expect(loaded.preset(preset)?.stageNames.title(of: 1) == "Precision")
        #expect(loaded.preset(preset)?.stageNames.title(of: 2) == "Stage 2")
        #expect(loaded.preset(preset)?.stageNames.title(of: 3) == "Gaming")
    }

    @Test func loadReturnsNothingBeforeTheFirstSave() {
        #expect(MappingStore(fileURL: fileURL).load() == nil)
    }

    @Test func loadIgnoresAFileItCannotDecode() throws {
        try write("not json")

        #expect(MappingStore(fileURL: fileURL).load() == nil)
    }

    @Test func aKeptCopySurvivesTheNextSave() throws {
        try write("not json")
        let store = MappingStore(fileURL: fileURL)

        let copy = try #require(try store.keepCopyOfSavedFile())
        try store.save(PresetLibrary())

        #expect(copy.lastPathComponent == "mappings.unreadable.json")
        #expect(try String(contentsOf: copy, encoding: .utf8) == "not json")
    }

    @Test func aLaterCopyLeavesAnEarlierOneInPlace() throws {
        let store = MappingStore(fileURL: fileURL)
        try write("first")
        let first = try #require(try store.keepCopyOfSavedFile())
        try write("second")

        let second = try #require(try store.keepCopyOfSavedFile())

        #expect(second.lastPathComponent == "mappings.unreadable-2.json")
        #expect(try String(contentsOf: first, encoding: .utf8) == "first")
        #expect(try String(contentsOf: second, encoding: .utf8) == "second")
    }

    @Test func thereIsNothingToKeepBeforeTheFirstSave() throws {
        #expect(try MappingStore(fileURL: fileURL).keepCopyOfSavedFile() == nil)
    }

    @Test func aFileSavedByVersion0_1StillLoads() throws {
        try write(Self.fileSavedByVersion0_1)

        let library = try #require(MappingStore(fileURL: fileURL).load())

        #expect(library.presets.map(\.id.uuidString) == [Self.everydayID, Self.gamesID])
        #expect(library.presets.map(\.name) == ["Everyday", "Games"])
        #expect(library.presets.map(\.symbol) == ["keyboard.fill", "computermouse.fill"])
        #expect(library.presets.map(\.table) == [Self.everydayTable, .factoryDefault])
        #expect(library.preset(in: .first)?.name == "Everyday")
        #expect(library.written(to: .first)?.table == .factoryDefault)
        #expect(library.written(to: .second) == nil)
    }

    @Test func aFileSavedBeforeDPIExistedLoadsWithFactoryDPIAndAnUnknownRecord() throws {
        try write(Self.fileSavedByVersion0_1)

        let library = try #require(MappingStore(fileURL: fileURL).load())

        #expect(library.presets.map(\.dpi) == [.factoryDefault, .factoryDefault])
        #expect(library.written(to: .first)?.dpi == nil)
        #expect(
            library.pendingUpdate(of: .first)
                == ProfileUpdate(buttons: Self.everydayTable, dpi: .factoryDefault, lighting: .factory(for: .first))
        )
        #expect(library.written(to: .second) == nil)
    }

    @Test func aFileSavedBeforeStageNamesExistedLoadsWithUnnamedStages() throws {
        try write(Self.fileSavedByVersion0_1)

        let library = try #require(MappingStore(fileURL: fileURL).load())

        #expect(library.presets.map(\.stageNames) == [.unnamed, .unnamed])
    }

    private func write(_ contents: String) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: fileURL)
    }
}

extension MappingStoreTests {
    static let everydayID = "11111111-1111-1111-1111-111111111111"
    static let gamesID = "22222222-2222-2222-2222-222222222222"

    /// Written by version 0.1. It uses every kind of action, so renaming anything that is part of
    /// the file breaks this test.
    static let fileSavedByVersion0_1 = #"""
        {"presets":[{"table":{"actionsInButtonOrder":[{"click":{"_0":240}},{"click":{"_0":241}},\#
        {"media":{"_0":205}},{"key":{"_0":{"modifiers":10,"key":{"usage":43}}}},\#
        {"windowNavigation":{"_0":{"system":"linux","command":"nextDesktop"}}},{"dpi":{"_0":1}},\#
        {"profile":{"_0":2}},{"multiClick":{"_0":{"times":3,"delayMilliseconds":80}}},{"disabled":{}},\#
        {"windowNavigation":{"_0":{"system":"macOS","command":"appWindows"}}},\#
        {"key":{"_0":{"modifiers":0,"key":{"usage":44}}}}]},"name":"Everyday",\#
        "id":"11111111-1111-1111-1111-111111111111","symbol":"keyboard.fill"},\#
        {"table":{"actionsInButtonOrder":[{"click":{"_0":240}},{"click":{"_0":241}},{"click":{"_0":242}},\#
        {"click":{"_0":244}},{"click":{"_0":243}},{"dpi":{"_0":3}},{"key":{"_0":{"key":{"usage":26},"modifiers":0}}},\#
        {"key":{"_0":{"key":{"usage":22},"modifiers":0}}},{"key":{"_0":{"key":{"usage":4},"modifiers":0}}},\#
        {"key":{"_0":{"key":{"usage":7},"modifiers":0}}},{"key":{"_0":{"key":{"usage":44},"modifiers":0}}}]},\#
        "symbol":"computermouse.fill","name":"Games","id":"22222222-2222-2222-2222-222222222222"}],\#
        "firstSlot":{"presetID":"11111111-1111-1111-1111-111111111111","table":{"actionsInButtonOrder":[\#
        {"click":{"_0":240}},{"click":{"_0":241}},{"click":{"_0":242}},{"click":{"_0":244}},{"click":{"_0":243}},\#
        {"dpi":{"_0":3}},{"key":{"_0":{"key":{"usage":26},"modifiers":0}}},{"key":{"_0":{"key":{"usage":22},"modifiers":0}}},\#
        {"key":{"_0":{"key":{"usage":4},"modifiers":0}}},{"key":{"_0":{"key":{"usage":7},"modifiers":0}}},\#
        {"key":{"_0":{"key":{"usage":44},"modifiers":0}}}]}}}
        """#

    static var everydayTable: ButtonTable {
        var everyday = ButtonTable.factoryDefault
        everyday[.wheelPress] = .media(.playPause)
        everyday[.thumbFront] = .key(KeyStroke(modifiers: [.command, .shift], key: .tab))
        everyday[.thumbRear] = .windowNavigation(WindowNavigation(system: .linux, command: .nextDesktop))
        everyday[.dpiButton] = .dpi(.up)
        everyday[.joystickUp] = .profile(.down)
        everyday[.joystickDown] = .multiClick(MultiClick(times: 3, delayMilliseconds: 80))
        everyday[.joystickLeft] = .disabled
        everyday[.joystickRight] = .windowNavigation(WindowNavigation(system: .macOS, command: .appWindows))
        return everyday
    }
}
