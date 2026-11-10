import Foundation

/// Names given to the five DPI stages. They are saved with the preset and never sent to the mouse.
public struct DPIStageNames: Equatable, Codable, Sendable {
    public static let unnamed = DPIStageNames(names: Array(repeating: "", count: DPISettings.stages.count))

    private var names: [String]

    private init(names: [String]) {
        self.names = names
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let names = try container.decode([String].self)
        guard names.count == DPISettings.stages.count else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected \(DPISettings.stages.count) stage names, found \(names.count)"
            )
        }
        self.names = names
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(names)
    }

    /// The name given to `stage` (one of `DPISettings.stages`), or "" when it has none. Setting trims whitespace.
    public subscript(stage: Int) -> String {
        get { names[stage - DPISettings.stages.lowerBound] }
        set { names[stage - DPISettings.stages.lowerBound] = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// The given name, or "Stage n" when there is none.
    public func title(of stage: Int) -> String {
        let name = self[stage]
        return name.isEmpty ? "Stage \(stage)" : name
    }
}
