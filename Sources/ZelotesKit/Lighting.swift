/// The mouse's lighting, which the mouse takes in the same table as the DPI stages.
public struct Lighting: Equatable, Codable, Sendable {
    public var effect: LightingEffect
    /// The color of the steady effect. The other effects cycle through every color.
    public var color: LightColor
    /// The brightness of the steady effect.
    public var brightness: LightBrightness
    /// The speed of breathing, neon, wave and flowing.
    public var speed: LightSpeed

    public init(effect: LightingEffect, color: LightColor, brightness: LightBrightness, speed: LightSpeed) {
        self.effect = effect
        self.color = color
        self.brightness = brightness
        self.speed = speed
    }

    /// Profile 1 starts with a red wave at medium speed, Profile 2 with steady blue at high brightness.
    public static func factory(for profile: MouseProfile) -> Lighting {
        switch profile {
        case .first: Lighting(effect: .wave, color: .red, brightness: .high, speed: .medium)
        case .second: Lighting(effect: .steady, color: .blue, brightness: .high, speed: .medium)
        }
    }
}

public enum LightingEffect: String, Codable, CaseIterable, Sendable {
    case steady
    case breathing
    case neon
    case wave
    case flowing
    case off
}

/// The colors the vendor software offers: each channel is either off or at the brightness's level.
public enum LightColor: String, Codable, CaseIterable, Sendable {
    case red
    case green
    case blue
    case yellow
    case magenta
    case cyan
    case white

    var channels: (red: Bool, green: Bool, blue: Bool) {
        switch self {
        case .red: (true, false, false)
        case .green: (false, true, false)
        case .blue: (false, false, true)
        case .yellow: (true, true, false)
        case .magenta: (true, false, true)
        case .cyan: (false, true, true)
        case .white: (true, true, true)
        }
    }
}

public enum LightBrightness: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public enum LightSpeed: String, Codable, CaseIterable, Sendable {
    case slow
    case medium
    case fast
}

/// Where the lighting sits in the `0x0C` table: bytes 7 to 9 are the effect, a speed or brightness, and a
/// parameter; bytes 40 to 63 are eight RGB triplets. The values are those of the vendor software. The published
/// protocol notes extrapolate effect speeds other than medium, and steady brightnesses other than high, from single
/// captures.
enum LightingBytes {
    static let effectOffset = 7
    static let colorsOffset = 40
    static let colorSlots = 8

    /// What the vendor software sends for every effect but steady: red, green, blue, yellow, magenta, cyan,
    /// white, white.
    private static let effectPalette: [LightColor] = [.red, .green, .blue, .yellow, .magenta, .cyan, .white, .white]

    static func patch(_ lighting: Lighting, into bytes: inout [UInt8]) {
        let block = effectBlock(of: lighting)
        bytes.replaceSubrange(effectOffset..<effectOffset + 3, with: block)
        let colors: [LightColor]
        let level: UInt8
        if lighting.effect == .steady {
            colors = Array(repeating: lighting.color, count: colorSlots)
            level = channelLevel(lighting.brightness)
        } else {
            colors = effectPalette
            level = channelLevel(.high)
        }
        let triplets = colors.flatMap { color -> [UInt8] in
            let channels = color.channels
            return [channels.red, channels.green, channels.blue].map { $0 ? level : 0 }
        }
        bytes.replaceSubrange(colorsOffset..<colorsOffset + triplets.count, with: triplets)
    }

    private static func effectBlock(of lighting: Lighting) -> [UInt8] {
        switch lighting.effect {
        case .off: [0x00, 0x00, 0x00]
        case .steady: [0x01, brightnessTier(lighting.brightness), 0x03]
        case .breathing: [0x02, pulseSpeed(lighting.speed), 0x0A]
        case .neon: [0x03, pulseSpeed(lighting.speed), 0x00]
        case .wave: [0x04, waveSpeed(lighting.speed), 0x10]
        case .flowing: [0x06, flowingSpeed(lighting.speed), 0x0A]
        }
    }

    private static func brightnessTier(_ brightness: LightBrightness) -> UInt8 {
        switch brightness {
        case .high: 0x01
        case .medium: 0x02
        case .low: 0x03
        }
    }

    private static func channelLevel(_ brightness: LightBrightness) -> UInt8 {
        switch brightness {
        case .high: 0x31
        case .medium: 0x20
        case .low: 0x10
        }
    }

    /// Breathing and neon share these speeds.
    private static func pulseSpeed(_ speed: LightSpeed) -> UInt8 {
        switch speed {
        case .fast: 0x04
        case .medium: 0x08
        case .slow: 0x0C
        }
    }

    private static func waveSpeed(_ speed: LightSpeed) -> UInt8 {
        switch speed {
        case .fast: 0x03
        case .medium: 0x06
        case .slow: 0x09
        }
    }

    private static func flowingSpeed(_ speed: LightSpeed) -> UInt8 {
        switch speed {
        case .fast: 0x3C
        case .medium: 0x5F
        case .slow: 0x78
        }
    }
}
