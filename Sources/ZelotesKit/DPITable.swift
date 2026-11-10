/// The 64-byte table the mouse takes after the prepare-DPI command. It also carries the profile's lighting.
struct DPITable {
    static let wireLength = 64

    /// The report the mouse expects ahead of the table.
    static let primer: [UInt8] = [0xFF, 0xFF] + [UInt8](repeating: 0, count: wireLength - 2)

    private static let firstStageXOffset = 20
    private static let firstStageYOffset = 28

    private static let highRangeFlag: UInt8 = 0x80
    private static let lowRangeLimit = 5000

    // Measured sensor codes, interpolated in between. 3300 and 3500 DPI are the measurements at 6600 and 7000
    // halved.
    private static let lowRangePoints: [(dpi: Double, code: UInt8)] = [
        (200, 0x04), (300, 0x06), (400, 0x08), (600, 0x0D), (800, 0x12), (1000, 0x16), (1200, 0x1B),
        (1600, 0x24), (2000, 0x2E), (2300, 0x34), (2400, 0x37), (2600, 0x3B), (3000, 0x45), (3200, 0x49),
        (3300, 0x4C), (3500, 0x50), (4800, 0x6F), (5000, 0x73),
    ]

    /// The vendor software's table for Profile 1 as it ships. Profile 2's differs only in the lighting, so this
    /// is the base for any lighting.
    private static let factoryBytes: [UInt8] = [
        0x0F, 0x00, 0x1E, 0x0A, 0x19, 0x19, 0x05, 0x04, 0x06, 0x10, 0x64, 0x64, 0x01, 0xC0, 0xF0, 0x03,
        0x01, 0x01, 0x19, 0x19, 0x22, 0x39, 0x5C, 0xD0, 0xF3, 0x5C, 0x73, 0x00, 0x22, 0x39, 0x5C, 0xD0,
        0xF3, 0x5C, 0x73, 0x00, 0x1F, 0xFF, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00, 0x31, 0x00, 0x00, 0x00,
        0x31, 0x31, 0x31, 0x00, 0x31, 0x00, 0x31, 0x00, 0x31, 0x31, 0x31, 0x31, 0x31, 0x31, 0x31, 0x31,
    ]

    let wireBytes: [UInt8]

    /// The table with the profile's factory lighting.
    init(_ settings: DPISettings, for profile: MouseProfile) {
        self.init(settings, lighting: .factory(for: profile))
    }

    init(_ settings: DPISettings, lighting: Lighting) {
        var bytes = Self.factoryBytes
        LightingBytes.patch(lighting, into: &bytes)
        for stage in DPISettings.stages {
            let code = Self.sensorCode(forDPI: settings[stage])
            let index = stage - DPISettings.stages.lowerBound
            bytes[Self.firstStageXOffset + index] = code
            bytes[Self.firstStageYOffset + index] = code
        }
        wireBytes = bytes
    }

    /// The code for a DPI within `DPISettings.dpiRange`. Above 5000 DPI the sensor takes the code of half
    /// the DPI with bit 7 set.
    static func sensorCode(forDPI dpi: Int) -> UInt8 {
        if dpi > lowRangeLimit {
            return highRangeFlag | lowRangeCode(forDPI: Double(dpi) / 2)
        }
        return lowRangeCode(forDPI: Double(dpi))
    }

    private static func lowRangeCode(forDPI dpi: Double) -> UInt8 {
        let first = lowRangePoints[0]
        let last = lowRangePoints[lowRangePoints.count - 1]
        let clamped = min(max(dpi, first.dpi), last.dpi)
        let upperIndex = lowRangePoints.firstIndex { $0.dpi >= clamped } ?? lowRangePoints.count - 1
        guard upperIndex > 0 else { return first.code }
        let lower = lowRangePoints[upperIndex - 1]
        let upper = lowRangePoints[upperIndex]
        let rise = Double(upper.code) - Double(lower.code)
        let code = Double(lower.code) + rise * (clamped - lower.dpi) / (upper.dpi - lower.dpi)
        return UInt8(code.rounded(.toNearestOrAwayFromZero))
    }
}
