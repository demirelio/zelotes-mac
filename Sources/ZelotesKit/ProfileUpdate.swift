/// What one transaction writes to a profile: either part may be left out.
public struct ProfileUpdate: Equatable, Sendable {
    public var buttons: ButtonTable?
    public var dpi: DPISettings?
    /// The lighting travels in the DPI table, so it is written only along with `dpi`; `nil` writes the
    /// profile's factory lighting.
    public var lighting: Lighting?

    public init(buttons: ButtonTable? = nil, dpi: DPISettings? = nil, lighting: Lighting? = nil) {
        self.buttons = buttons
        self.dpi = dpi
        self.lighting = lighting
    }

    public static func everything(of preset: Preset) -> ProfileUpdate {
        ProfileUpdate(buttons: preset.table, dpi: preset.dpi, lighting: preset.lighting)
    }
}
