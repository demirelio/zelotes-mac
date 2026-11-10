import Foundation

public struct Preset: Identifiable, Equatable, Codable, Sendable {
    public static let defaultSymbol = "computermouse.fill"
    public static let untitledName = "Untitled"

    public let id: UUID
    public var name: String
    /// Name of the SF Symbol shown next to the preset.
    public var symbol: String
    public var table: ButtonTable
    public var dpi: DPISettings
    public var stageNames: DPIStageNames
    public var pointer: PointerSettings
    public var lighting: Lighting

    /// A new preset lights up like Profile 1 does as it ships.
    public static let defaultLighting = Lighting.factory(for: .first)

    public init(
        id: UUID = UUID(),
        name: String,
        symbol: String = Preset.defaultSymbol,
        table: ButtonTable = .factoryDefault,
        dpi: DPISettings = .factoryDefault,
        stageNames: DPIStageNames = .unnamed,
        pointer: PointerSettings = .standard,
        lighting: Lighting = Preset.defaultLighting
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.table = table
        self.dpi = dpi
        self.stageNames = stageNames
        self.pointer = pointer
        self.lighting = lighting
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        table = try container.decode(ButtonTable.self, forKey: .table)
        dpi = try container.decodeIfPresent(DPISettings.self, forKey: .dpi) ?? .factoryDefault
        stageNames = try container.decodeIfPresent(DPIStageNames.self, forKey: .stageNames) ?? .unnamed
        pointer = try container.decodeIfPresent(PointerSettings.self, forKey: .pointer) ?? .standard
        lighting = try container.decodeIfPresent(Lighting.self, forKey: .lighting) ?? Self.defaultLighting
    }

    /// The name to show: a preset may be left without one.
    public var displayName: String {
        name.isEmpty ? Self.untitledName : name
    }
}

/// What this app last wrote into one of the mouse's profiles. The mouse itself cannot be read back.
public struct WrittenSlot: Equatable, Codable, Sendable {
    public let presetID: Preset.ID
    public let table: ButtonTable
    /// `nil` when this app has not written DPI settings to the profile.
    public let dpi: DPISettings?
    /// `nil` when no lighting was recorded: the profile is then taken to hold its factory lighting.
    public let lighting: Lighting?

    func lighting(of profile: MouseProfile) -> Lighting {
        lighting ?? .factory(for: profile)
    }
}

/// Reads only whether a saved preset has lighting.
private struct SavedLighting: Decodable {
    let lighting: Lighting?
}

/// The user's presets, never empty, plus the record of what was written to each mouse profile.
public struct PresetLibrary: Equatable, Codable, Sendable {
    public private(set) var presets: [Preset]
    private var firstSlot: WrittenSlot?
    private var secondSlot: WrittenSlot?
    /// The profile this app last made active. A profile button on the mouse can change it without the Mac knowing.
    public private(set) var activeProfile: MouseProfile?

    public init() {
        presets = [Preset(name: "Default")]
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        presets = try container.decode([Preset].self, forKey: .presets)
        guard !presets.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .presets,
                in: container,
                debugDescription: "A preset library needs at least one preset"
            )
        }
        firstSlot = try container.decodeIfPresent(WrittenSlot.self, forKey: .firstSlot)
        secondSlot = try container.decodeIfPresent(WrittenSlot.self, forKey: .secondSlot)
        activeProfile = try container.decodeIfPresent(MouseProfile.self, forKey: .activeProfile)
        // A preset saved without lighting takes the lighting of the profile it is in, which is what the mouse
        // shows, so it does not count as changed.
        let savedLighting = try container.decode([SavedLighting].self, forKey: .presets)
        for (index, saved) in savedLighting.enumerated() where saved.lighting == nil {
            if let profile = profile(holding: presets[index].id), let written = written(to: profile) {
                presets[index].lighting = written.lighting(of: profile)
            }
        }
    }

    /// The preset this app last wrote to `profile`, if it still exists.
    public func preset(in profile: MouseProfile) -> Preset? {
        written(to: profile).flatMap { preset($0.presetID) }
    }

    public func profile(holding presetID: Preset.ID) -> MouseProfile? {
        MouseProfile.allCases.first { written(to: $0)?.presetID == presetID }
    }

    /// Presets that are stored on this Mac only.
    public var reservePresets: [Preset] {
        presets.filter { profile(holding: $0.id) == nil }
    }

    /// Whether the preset in `profile` is unchanged since it was written there.
    public func isUpToDate(_ profile: MouseProfile) -> Bool {
        pendingUpdate(of: profile) == nil
    }

    /// The parts of the preset in `profile` that differ from what was written there, or `nil` when none do,
    /// nothing was written, or the preset no longer exists. DPI counts as differing when none was written.
    /// DPI and lighting share a table, so a change to either sends both.
    public func pendingUpdate(of profile: MouseProfile) -> ProfileUpdate? {
        guard let written = written(to: profile), let preset = preset(written.presetID) else { return nil }
        let dpiTableIsCurrent = preset.dpi == written.dpi && preset.lighting == written.lighting(of: profile)
        let update = ProfileUpdate(
            buttons: preset.table == written.table ? nil : preset.table,
            dpi: dpiTableIsCurrent ? nil : preset.dpi,
            lighting: dpiTableIsCurrent ? nil : preset.lighting
        )
        return update == ProfileUpdate() ? nil : update
    }

    /// Forgets what was written to `profile`. The mouse keeps the table it has.
    public mutating func clearRecord(of profile: MouseProfile) {
        setRecord(nil, of: profile)
    }

    public func preset(_ id: Preset.ID) -> Preset? {
        presets.first { $0.id == id }
    }

    /// Adds a preset with factory defaults, or a copy of `sourceID` when given, and returns its id.
    @discardableResult
    public mutating func addPreset(copying sourceID: Preset.ID? = nil) -> Preset.ID {
        let source = sourceID.flatMap(preset)
        let added = Preset(
            name: unusedName(copying: source),
            symbol: source?.symbol ?? Preset.defaultSymbol,
            table: source?.table ?? .factoryDefault,
            dpi: source?.dpi ?? .factoryDefault,
            stageNames: source?.stageNames ?? .unnamed,
            pointer: source?.pointer ?? .standard,
            lighting: source?.lighting ?? Preset.defaultLighting
        )
        presets.append(added)
        return added.id
    }

    /// Does nothing when `id` is the only preset left.
    public mutating func removePreset(_ id: Preset.ID) {
        guard presets.count > 1 else { return }
        presets.removeAll { $0.id == id }
    }

    public mutating func updatePreset(_ id: Preset.ID, _ change: (inout Preset) -> Void) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        change(&presets[index])
    }

    public func written(to profile: MouseProfile) -> WrittenSlot? {
        switch profile {
        case .first: firstSlot
        case .second: secondSlot
        }
    }

    public mutating func recordWrite(of preset: Preset, to profile: MouseProfile) {
        setRecord(
            WrittenSlot(presetID: preset.id, table: preset.table, dpi: preset.dpi, lighting: preset.lighting),
            of: profile
        )
    }

    /// Records `stage` as the one the mouse uses in `profile`. Changes nothing when no DPI settings were written
    /// there, because the mouse's DPI table is then unknown.
    public mutating func recordStageSelection(_ stage: Int, in profile: MouseProfile) {
        guard let written = written(to: profile), var dpi = written.dpi else { return }
        dpi.activeStage = stage
        setRecord(
            WrittenSlot(presetID: written.presetID, table: written.table, dpi: dpi, lighting: written.lighting),
            of: profile
        )
    }

    /// Every transaction ends by making its profile the active one, so call this after each one that succeeded.
    public mutating func recordActivation(of profile: MouseProfile) {
        activeProfile = profile
    }

    /// The profile the mouse is taken to use: the one last made active, or Profile 1 before the app has made one active.
    public var profileInUse: MouseProfile {
        activeProfile ?? .first
    }

    /// Whether a preset in either profile has pointer settings of its own, which macOS needs again each time the
    /// mouse is plugged in.
    public var usesPointerSettings: Bool {
        MouseProfile.allCases.contains { preset(in: $0)?.pointer.curve != nil }
    }

    /// The pointer settings of the preset in the profile in use, at the DPI of that profile's active stage as written.
    public var pointerTarget: PointerTarget {
        guard let preset = preset(in: profileInUse) else {
            return PointerTarget(settings: .standard, dpi: DPISettings.factoryDefault[DPISettings.factoryDefault.activeStage])
        }
        let dpi = written(to: profileInUse)?.dpi ?? preset.dpi
        return PointerTarget(settings: preset.pointer, dpi: dpi[dpi.activeStage])
    }

    private mutating func setRecord(_ slot: WrittenSlot?, of profile: MouseProfile) {
        switch profile {
        case .first: firstSlot = slot
        case .second: secondSlot = slot
        }
    }

    private func unusedName(copying source: Preset?) -> String {
        let taken = Set(presets.map(\.name))
        let base = source.map { "\($0.displayName) copy" } ?? "Preset"
        if source != nil, !taken.contains(base) {
            return base
        }
        var number = 2
        while taken.contains("\(base) \(number)") {
            number += 1
        }
        return "\(base) \(number)"
    }
}
