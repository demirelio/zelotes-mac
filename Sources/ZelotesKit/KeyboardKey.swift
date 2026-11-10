public struct KeyboardKey: Hashable, Codable, Sendable {
    /// Usage on the USB HID Keyboard/Keypad page.
    public let usage: UInt8

    public init(usage: UInt8) {
        self.usage = usage
    }
}

public struct KeyboardKeyGroup: Identifiable, Sendable {
    public let title: String
    public let keys: [KeyboardKey]

    public var id: String { title }
}

extension KeyboardKey {
    public static let a = KeyboardKey(usage: 0x04)
    public static let d = KeyboardKey(usage: 0x07)
    public static let s = KeyboardKey(usage: 0x16)
    public static let w = KeyboardKey(usage: 0x1A)
    public static let space = KeyboardKey(usage: 0x2C)
    public static let tab = KeyboardKey(usage: 0x2B)
    public static let f11 = KeyboardKey(usage: 0x44)
    public static let rightArrow = KeyboardKey(usage: 0x4F)
    public static let leftArrow = KeyboardKey(usage: 0x50)
    public static let downArrow = KeyboardKey(usage: 0x51)
    public static let upArrow = KeyboardKey(usage: 0x52)

    public var name: String {
        Self.namesByUsage[usage] ?? "Key \(usage)"
    }

    public static let groups: [KeyboardKeyGroup] = catalog.map { group in
        KeyboardKeyGroup(title: group.title, keys: group.keys.map { KeyboardKey(usage: $0.usage) })
    }

    private typealias NamedUsage = (usage: UInt8, name: String)

    private static let namesByUsage: [UInt8: String] = Dictionary(
        uniqueKeysWithValues: catalog.flatMap(\.keys).map { ($0.usage, $0.name) }
    )

    private static let catalog: [(title: String, keys: [NamedUsage])] = [
        ("Letters", zip(UInt8(0x04)...0x1D, "ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { ($0, String($1)) }),
        ("Digits", zip(UInt8(0x1E)...0x27, "1234567890").map { ($0, String($1)) }),
        ("Editing", [
            (0x28, "Return"), (0x29, "Escape"), (0x2A, "Delete"), (0x4C, "Forward Delete"),
            (0x2B, "Tab"), (0x2C, "Space"),
        ]),
        ("Navigation", [
            (0x52, "↑"), (0x51, "↓"), (0x50, "←"), (0x4F, "→"),
            (0x4A, "Home"), (0x4D, "End"), (0x4B, "Page Up"), (0x4E, "Page Down"),
        ]),
        ("Symbols", [
            (0x2D, "-"), (0x2E, "="), (0x2F, "["), (0x30, "]"), (0x31, "\\"), (0x33, ";"),
            (0x34, "'"), (0x35, "`"), (0x36, ","), (0x37, "."), (0x38, "/"),
        ]),
        ("Function Keys",
         zip(UInt8(0x3A)...0x45, 1...12).map { ($0, "F\($1)") }
            + zip(UInt8(0x68)...0x6F, 13...20).map { ($0, "F\($1)") }),
    ]
}
