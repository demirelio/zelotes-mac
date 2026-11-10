public enum ButtonAction: Equatable, Codable, Sendable {
    case disabled
    case click(MouseClick)
    case key(KeyStroke)
    case windowNavigation(WindowNavigation)
    case media(MediaKey)
    case dpi(StepDirection)
    case profile(StepDirection)
    case multiClick(MultiClick)
}

public enum MouseClick: UInt16, CaseIterable, Codable, Sendable {
    case left = 0xF0
    case right = 0xF1
    case middle = 0xF2
    case back = 0xF3
    case forward = 0xF4
}

/// Raw values are usages on the USB HID Consumer page.
public enum MediaKey: UInt16, CaseIterable, Codable, Sendable {
    case playPause = 0xCD
    case nextTrack = 0xB5
    case previousTrack = 0xB6
    case stop = 0xB7
    case volumeUp = 0xE9
    case volumeDown = 0xEA
    case mute = 0xE2
}

public enum StepDirection: UInt16, CaseIterable, Codable, Sendable {
    case up = 1
    case down = 2
    case cycle = 3
}

/// Raw value is the low nibble of a USB HID keyboard modifier byte.
public struct KeyModifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let control = KeyModifiers(rawValue: 0x01)
    public static let shift = KeyModifiers(rawValue: 0x02)
    public static let option = KeyModifiers(rawValue: 0x04)
    public static let command = KeyModifiers(rawValue: 0x08)
}

public struct KeyStroke: Equatable, Codable, Sendable {
    public var modifiers: KeyModifiers
    public var key: KeyboardKey

    public init(modifiers: KeyModifiers = [], key: KeyboardKey) {
        self.modifiers = modifiers
        self.key = key
    }
}

public struct MultiClick: Equatable, Codable, Sendable {
    /// The firmware stores the delay in a signed byte.
    public static let maximumDelayMilliseconds: UInt8 = 127
    public static let doubleClick = MultiClick(times: 2, delayMilliseconds: 50)

    public var times: UInt8
    public var delayMilliseconds: UInt8

    public init(times: UInt8, delayMilliseconds: UInt8) {
        self.times = times
        self.delayMilliseconds = delayMilliseconds
    }
}

struct WireBinding: Equatable {
    let type: UInt16
    let value: UInt16

    var littleEndianBytes: [UInt8] {
        [UInt8(type & 0xFF), UInt8(type >> 8), UInt8(value & 0xFF), UInt8(value >> 8)]
    }
}

private enum BindingType {
    static let keyboard: UInt16 = 0x0000
    static let mouseClick: UInt16 = 0x0001
    static let media: UInt16 = 0x0003
    static let dpi: UInt16 = 0x0007
    static let profile: UInt16 = 0x0008
    static let multiClick: UInt16 = 0xF00A
}

extension KeyStroke {
    /// A key binding carries its modifiers in the high byte of the type.
    var wireBinding: WireBinding {
        WireBinding(type: BindingType.keyboard | UInt16(modifiers.rawValue) << 8, value: UInt16(key.usage))
    }
}

extension ButtonAction {
    var wireBinding: WireBinding {
        switch self {
        case .disabled:
            WireBinding(type: BindingType.keyboard, value: 0)
        case .click(let click):
            WireBinding(type: BindingType.mouseClick, value: click.rawValue)
        case .key(let stroke):
            stroke.wireBinding
        case .windowNavigation(let navigation):
            navigation.keyStroke?.wireBinding ?? ButtonAction.disabled.wireBinding
        case .media(let key):
            WireBinding(type: BindingType.media, value: key.rawValue)
        case .dpi(let step):
            WireBinding(type: BindingType.dpi, value: step.rawValue)
        case .profile(let step):
            WireBinding(type: BindingType.profile, value: step.rawValue)
        case .multiClick(let multiClick):
            WireBinding(
                type: BindingType.multiClick,
                value: UInt16(multiClick.times) << 8
                    | UInt16(min(multiClick.delayMilliseconds, MultiClick.maximumDelayMilliseconds))
            )
        }
    }
}
