/// Everything the DPI page sets: five DPI stages, the active stage, and the polling rate.
public struct DPISettings: Equatable, Codable, Sendable {
    public static let stages = 1...5
    public static let dpiRange = 200...10_000
    public static let dpiStep = 100

    public static let factoryDefault = DPISettings(
        dpiByStage: [1500, 2500, 4000, 7000, 10_000],
        activeStage: 1,
        pollingRate: .factoryDefault
    )

    private var dpiByStage: [Int]

    /// The stage the mouse uses, sent with every DPI write.
    public var activeStage: Int {
        didSet { activeStage = min(max(activeStage, Self.stages.lowerBound), Self.stages.upperBound) }
    }

    public var pollingRate: PollingRate

    private enum CodingKeys: String, CodingKey {
        case dpiByStage
        // Saved preset files already use these keys.
        case activeStage = "startingStage"
        case pollingRate = "reportRate"
    }

    private init(dpiByStage: [Int], activeStage: Int, pollingRate: PollingRate) {
        self.dpiByStage = dpiByStage
        self.activeStage = activeStage
        self.pollingRate = pollingRate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dpiByStage = try container.decode([Int].self, forKey: .dpiByStage)
        guard dpiByStage.count == Self.stages.count else {
            throw DecodingError.dataCorruptedError(
                forKey: .dpiByStage,
                in: container,
                debugDescription: "Expected \(Self.stages.count) DPI stages, found \(dpiByStage.count)"
            )
        }
        guard dpiByStage.allSatisfy(Self.dpiRange.contains) else {
            throw DecodingError.dataCorruptedError(
                forKey: .dpiByStage,
                in: container,
                debugDescription: "DPI values must lie within \(Self.dpiRange)"
            )
        }
        let activeStage = try container.decode(Int.self, forKey: .activeStage)
        guard Self.stages.contains(activeStage) else {
            throw DecodingError.dataCorruptedError(
                forKey: .activeStage,
                in: container,
                debugDescription: "The active stage must be one of \(Self.stages)"
            )
        }
        self.dpiByStage = dpiByStage
        self.activeStage = activeStage
        pollingRate = try container.decode(PollingRate.self, forKey: .pollingRate)
    }

    /// The DPI of `stage`, which must be one of `stages`.
    /// Setting rounds to the nearest `dpiStep` and keeps the value within `dpiRange`.
    public subscript(stage: Int) -> Int {
        get { dpiByStage[stage - Self.stages.lowerBound] }
        set { dpiByStage[stage - Self.stages.lowerBound] = Self.normalized(newValue) }
    }

    public static func normalized(_ dpi: Int) -> Int {
        let inRange = min(max(dpi, dpiRange.lowerBound), dpiRange.upperBound)
        return (inRange + dpiStep / 2) / dpiStep * dpiStep
    }
}
