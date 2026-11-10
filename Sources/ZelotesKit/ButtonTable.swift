/// The assignment of all eleven buttons for one profile. The mouse only accepts the table as a whole.
public struct ButtonTable: Equatable, Codable, Sendable {
    public static let wireLength = 64

    public static let factoryDefault = ButtonTable(actionsInButtonOrder: [
        .click(.left),
        .click(.right),
        .click(.middle),
        .click(.forward),
        .click(.back),
        .dpi(.cycle),
        .key(KeyStroke(key: .w)),
        .key(KeyStroke(key: .s)),
        .key(KeyStroke(key: .a)),
        .key(KeyStroke(key: .d)),
        .key(KeyStroke(key: .space)),
    ])

    private var actionsInButtonOrder: [ButtonAction]

    private init(actionsInButtonOrder: [ButtonAction]) {
        self.actionsInButtonOrder = actionsInButtonOrder
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actions = try container.decode([ButtonAction].self, forKey: .actionsInButtonOrder)
        guard actions.count == MouseButton.allCases.count else {
            throw DecodingError.dataCorruptedError(
                forKey: .actionsInButtonOrder,
                in: container,
                debugDescription: "Expected \(MouseButton.allCases.count) button actions, found \(actions.count)"
            )
        }
        actionsInButtonOrder = actions
    }

    public subscript(button: MouseButton) -> ButtonAction {
        get { actionsInButtonOrder[button.rawValue - 1] }
        set { actionsInButtonOrder[button.rawValue - 1] = newValue }
    }

    /// Without a Left Click button the mouse cannot click until the table is replaced.
    public var hasLeftClick: Bool {
        actionsInButtonOrder.contains(.click(.left))
    }

    public var wireBytes: [UInt8] {
        var bytes = Self.reservedBytes
        for button in MouseButton.allCases {
            let slot = button.tableOffset..<button.tableOffset + 4
            bytes.replaceSubrange(slot, with: self[button].wireBinding.littleEndianBytes)
        }
        return bytes
    }

    // The bytes outside the button slots are undocumented; the vendor software always sends these values.
    private static let reservedBytes: [UInt8] = {
        var bytes = [UInt8](repeating: 0, count: wireLength)
        bytes.replaceSubrange(56..<64, with: [0x04, 0x00, 0x01, 0x00, 0x04, 0x00, 0x02, 0x00])
        return bytes
    }()
}
