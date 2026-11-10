import Foundation
import Testing
@testable import ZelotesKit

@Suite struct ButtonTableTests {
    static let tableSentByVendorRestoreDefaults: [UInt8] = [
        0x01, 0x00, 0xF0, 0x00, 0x01, 0x00, 0xF1, 0x00, 0x01, 0x00, 0xF2, 0x00, 0x01, 0x00, 0xF4, 0x00,
        0x01, 0x00, 0xF3, 0x00, 0x07, 0x00, 0x03, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x1A, 0x00, 0x00, 0x00, 0x16, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x07, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x04, 0x00, 0x02, 0x00,
    ]

    @Test func factoryDefaultEncodesToTheTableTheVendorSoftwareSends() {
        #expect(ButtonTable.factoryDefault.wireBytes == Self.tableSentByVendorRestoreDefaults)
    }

    @Test func remappingOneButtonChangesOnlyItsFourBytes() {
        var table = ButtonTable.factoryDefault
        table[.joystickPress] = .key(KeyStroke(modifiers: .command, key: KeyboardKey(usage: 0x06)))

        var expected = Self.tableSentByVendorRestoreDefaults
        expected.replaceSubrange(24..<28, with: [0x00, 0x08, 0x06, 0x00])
        #expect(table.wireBytes == expected)
    }

    @Test func everyButtonHasItsOwnSlot() {
        let offsets = MouseButton.allCases.map(\.tableOffset)
        #expect(Set(offsets).count == MouseButton.allCases.count)
    }

    @Test func decodingRejectsATableWithMissingButtons() {
        let truncated = Data(#"{"actionsInButtonOrder":[]}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ButtonTable.self, from: truncated)
        }
    }

    @Test func aTableHasLeftClickWhereverTheLeftClickIs() {
        var table = ButtonTable.factoryDefault
        #expect(table.hasLeftClick)

        table[.leftButton] = .disabled
        #expect(!table.hasLeftClick)

        table[.joystickPress] = .click(.left)
        #expect(table.hasLeftClick)
    }

    @Test func aKeyStrokeCarriesItsModifiersInTheHighByteOfTheType() {
        let stroke = KeyStroke(modifiers: [.command, .shift], key: .d)

        #expect(stroke.wireBinding == WireBinding(type: 0x0A00, value: 0x07))
    }

    @Test(arguments: [
        (ButtonAction.disabled, [0x00, 0x00, 0x00, 0x00] as [UInt8]),
        (.click(.left), [0x01, 0x00, 0xF0, 0x00]),
        (.click(.right), [0x01, 0x00, 0xF1, 0x00]),
        (.key(KeyStroke(key: .space)), [0x00, 0x00, 0x2C, 0x00]),
        (.key(KeyStroke(modifiers: .option, key: .space)), [0x00, 0x04, 0x2C, 0x00]),
        (.key(KeyStroke(modifiers: [.control, .shift], key: .a)), [0x00, 0x03, 0x04, 0x00]),
        (.key(KeyStroke(modifiers: [.control, .shift, .option, .command], key: .tab)), [0x00, 0x0F, 0x2B, 0x00]),
        (.windowNavigation(WindowNavigation(system: .macOS, command: .nextDesktop)), [0x00, 0x01, 0x4F, 0x00]),
        (.windowNavigation(WindowNavigation(system: .windows, command: .previousDesktop)), [0x00, 0x09, 0x50, 0x00]),
        (.windowNavigation(WindowNavigation(system: .windows, command: .appWindows)), [0x00, 0x00, 0x00, 0x00]),
        (.media(.volumeUp), [0x03, 0x00, 0xE9, 0x00]),
        (.dpi(.up), [0x07, 0x00, 0x01, 0x00]),
        (.profile(.cycle), [0x08, 0x00, 0x03, 0x00]),
        (.multiClick(.doubleClick), [0x0A, 0xF0, 0x32, 0x02]),
        (.multiClick(MultiClick(times: 50, delayMilliseconds: 200)), [0x0A, 0xF0, 0x7F, 0x32]),
    ])
    func actionEncodesToItsSlotBytes(action: ButtonAction, slotBytes: [UInt8]) {
        #expect(action.wireBinding.littleEndianBytes == slotBytes)
    }
}
