import Foundation

/// How the Mac moves the pointer for this mouse. Kept on the Mac: the mouse never receives it.
public struct PointerSettings: Equatable, Codable, Sendable {
    public static let speedRange = 0.1...4.0
    public static let standard = PointerSettings()

    public var acceleration = PointerAcceleration.macOS
    /// Points the pointer moves for each count of the sensor while the hand moves slowly.
    public var speed = 1.0 {
        didSet { speed = speed.clamped(to: Self.speedRange) }
    }
    public var custom = CustomCurve.standard

    public init() {}

    /// The curve the app gives macOS, or `nil` when macOS uses its own.
    public var curve: AccelerationCurve? {
        switch acceleration {
        case .macOS: nil
        case .windows: .windows
        case .none: AccelerationCurve.none
        case .custom: .custom(custom)
        }
    }
}

public enum PointerAcceleration: String, Codable, CaseIterable, Sendable {
    case macOS
    case windows
    case none
    case custom
}

/// A gain that stays at 1 up to `threshold`, then rises at `strength` and levels off towards `limit`.
public struct CustomCurve: Equatable, Codable, Sendable {
    /// Gain added per inch per second of hand speed above the threshold.
    public static let strengthRange = 0.02...1.0
    /// Inches per second.
    public static let thresholdRange = 0.0...10.0
    public static let limitRange = 1.0...6.0
    public static let standard = CustomCurve(strength: 0.3, threshold: 0.5, limit: 3)

    public var strength: Double {
        didSet { strength = strength.clamped(to: Self.strengthRange) }
    }
    public var threshold: Double {
        didSet { threshold = threshold.clamped(to: Self.thresholdRange) }
    }
    public var limit: Double {
        didSet { limit = limit.clamped(to: Self.limitRange) }
    }

    public init(strength: Double, threshold: Double, limit: Double) {
        self.strength = strength.clamped(to: Self.strengthRange)
        self.threshold = threshold.clamped(to: Self.thresholdRange)
        self.limit = limit.clamped(to: Self.limitRange)
    }

    func gain(atHandSpeed inchesPerSecond: Double) -> Double {
        let headroom = limit - 1
        guard headroom > 0 else { return 1 }
        let excess = max(0, inchesPerSecond - threshold)
        return 1 + headroom * (1 - exp(-strength * excess / headroom))
    }
}

public enum AccelerationCurve: Equatable, Sendable {
    case windows
    case none
    case custom(CustomCurve)

    /// How many times farther the pointer moves than at slow speed, with the hand moving at `inchesPerSecond`.
    public func gain(atHandSpeed inchesPerSecond: Double) -> Double {
        switch self {
        case .windows: WindowsCurve.gain(atHandSpeed: inchesPerSecond)
        case .none: 1
        case .custom(let curve): curve.gain(atHandSpeed: inchesPerSecond)
        }
    }

    /// Hand speeds where the gain changes slope, which a drawing or a table has to include to follow the curve exactly.
    public var corners: [Double] {
        switch self {
        case .windows: WindowsCurve.points.map(\.mouse)
        case .none: []
        case .custom(let curve): [curve.threshold]
        }
    }
}

/// Enhance Pointer Precision, the acceleration of Windows.
enum WindowsCurve {
    /// Windows' default `SmoothMouseXCurve` and `SmoothMouseYCurve`: mouse speed against pointer speed, both in
    /// inches per second, joined by straight lines from the origin. Windows 7 and later multiply the pointer
    /// speeds by 25/32, which changes how fast the pointer is but not the shape of the gain.
    static let points: [(mouse: Double, pointer: Double)] = [(0.43, 1.37), (1.25, 5.30), (3.86, 24.30), (40, 568)]

    /// Pointer speed over mouse speed, divided by its value for slow movements.
    static func gain(atHandSpeed inchesPerSecond: Double) -> Double {
        let slowGain = points[0].pointer / points[0].mouse
        guard inchesPerSecond > points[0].mouse else { return 1 }
        let upper = points.firstIndex { $0.mouse >= inchesPerSecond } ?? points.count - 1
        let (low, high) = (points[upper - 1], points[upper])
        let slope = (high.pointer - low.pointer) / (high.mouse - low.mouse)
        let pointerSpeed = low.pointer + slope * (inchesPerSecond - low.mouse)
        return pointerSpeed / inchesPerSecond / slowGain
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
