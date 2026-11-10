/// How many times a second the mouse sends its movement to the computer. The raw value is hertz.
public enum PollingRate: Int, CaseIterable, Codable, Sendable {
    case hz125 = 125
    case hz250 = 250
    case hz500 = 500
    case hz1000 = 1000

    public static let factoryDefault = PollingRate.hz500

    /// Milliseconds between two reports, as the mouse takes it.
    var pollingInterval: UInt8 {
        UInt8(1000 / rawValue)
    }
}
