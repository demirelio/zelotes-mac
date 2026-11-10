import SwiftUI
import ZelotesKit

struct PresetSidebar: View {
    let model: MappingModel
    @State private var dropTarget: DropTarget?

    var body: some View {
        List(selection: selection) {
            ForEach(MouseProfile.allCases, id: \.self) { profile in
                Section("Profile \(profile.rawValue)") {
                    Group {
                        if let preset = model.preset(in: profile) {
                            row(for: preset, hasPendingChanges: !model.isUpToDate(profile), activity: activity(of: profile))
                        } else {
                            EmptySlotRow(text: "Drop a preset here")
                        }
                    }
                    .dropDestination(for: String.self) { identifiers, _ in
                        drop(identifiers) { model.requestAssign($0, to: profile) }
                    } isTargeted: { isTargeted in
                        setTargeted(isTargeted, .profile(profile))
                    }
                    .listRowBackground(highlight(for: .profile(profile)))
                }
            }
            Section("Reserve") {
                Group {
                    if model.reservePresets.isEmpty {
                        EmptySlotRow(text: "No presets in reserve")
                    } else {
                        ForEach(model.reservePresets) { preset in
                            row(for: preset, hasPendingChanges: false)
                        }
                    }
                }
                .dropDestination(for: String.self) { identifiers, _ in
                    drop(identifiers) { model.moveToReserve($0) }
                } isTargeted: { isTargeted in
                    setTargeted(isTargeted, .reserve)
                }
                .listRowBackground(highlight(for: .reserve))
            }
            Section("Library") {
                Label("Macros", systemImage: "record.circle")
                    .tag(SidebarItem.macros)
            }
        }
        .onDeleteCommand {
            if !model.isShowingMacros {
                model.requestDelete(model.selectedPresetID)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DeviceStatus(isConnected: model.isMouseConnected)
        }
        .toolbar {
            ToolbarItem {
                Button("New Preset", systemImage: "plus") { model.addPreset() }
                    .help("New Preset")
            }
        }
    }

    private func row(
        for preset: Preset,
        hasPendingChanges: Bool,
        activity: ProfileActivity = .notInProfile
    ) -> some View {
        let isBeingEdited = preset.id == model.selectedPresetID && model.hasUnsavedChanges
        return PresetRow(preset: preset, hasPendingChanges: hasPendingChanges || isBeingEdited, activity: activity)
            .tag(SidebarItem.preset(preset.id))
            .draggable(preset.id.uuidString)
            .contextMenu {
                PresetActions(model: model, presetID: preset.id)
            }
    }

    private func activity(of profile: MouseProfile) -> ProfileActivity {
        if model.activeProfile == profile {
            return .active
        }
        return .inactive(isEnabled: model.canMakeProfileActive) { model.makeActive(profile) }
    }

    private func drop(_ identifiers: [String], _ place: (Preset.ID) -> Void) -> Bool {
        guard let presetID = identifiers.first.flatMap(UUID.init(uuidString:)) else { return false }
        place(presetID)
        return true
    }

    private func setTargeted(_ isTargeted: Bool, _ target: DropTarget) {
        if isTargeted {
            dropTarget = target
        } else if dropTarget == target {
            dropTarget = nil
        }
    }

    private func highlight(for target: DropTarget) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.tint.opacity(dropTarget == target ? 0.22 : 0))
            .padding(.horizontal, 10)
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { model.isShowingMacros ? .macros : .preset(model.selectedPresetID) },
            set: { newSelection in
                switch newSelection {
                case .preset(let id): model.showPreset(id)
                case .macros: model.showMacros()
                case nil: break
                }
            }
        )
    }
}

private enum SidebarItem: Hashable {
    case preset(Preset.ID)
    case macros
}

private enum DropTarget: Equatable {
    case profile(MouseProfile)
    case reserve
}

/// The menu items that act on one preset, shared by the sidebar's context menu and the toolbar's More menu.
struct PresetActions: View {
    let model: MappingModel
    let presetID: Preset.ID

    var body: some View {
        let location = model.profile(holding: presetID)
        ForEach(MouseProfile.allCases, id: \.self) { profile in
            Button("Move to Profile \(profile.rawValue)", systemImage: "\(profile.rawValue).circle") {
                model.requestAssign(presetID, to: profile)
            }
            .disabled(location == profile || !model.isMouseConnected)
        }
        Button("Move to Reserve", systemImage: "tray.and.arrow.down") {
            model.moveToReserve(presetID)
        }
        .disabled(location == nil)
        Divider()
        Button("Rename", systemImage: "pencil") {
            model.renamePreset(presetID)
        }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            model.duplicatePreset(presetID)
        }
        Button("Reset to Factory Defaults", systemImage: "arrow.counterclockwise") {
            model.resetPreset(presetID)
        }
        Divider()
        Button("Delete…", systemImage: "trash", role: .destructive) {
            model.requestDelete(presetID)
        }
        .disabled(!model.canDeletePresets)
    }
}

/// Whether a sidebar row's profile is the active one on the mouse.
private enum ProfileActivity {
    case notInProfile
    case active
    case inactive(isEnabled: Bool, makeActive: () -> Void)
}

private struct PresetRow: View {
    let preset: Preset
    let hasPendingChanges: Bool
    let activity: ProfileActivity
    @State private var isHovered = false

    var body: some View {
        Label {
            HStack(spacing: 6) {
                Text(preset.displayName)
                    .lineLimit(1)
                Spacer(minLength: 4)
                switch activity {
                case .notInProfile:
                    EmptyView()
                case .active:
                    ActivePill()
                        .help("The mouse uses this profile")
                case .inactive(let isEnabled, let makeActive):
                    if isHovered {
                        MakeActivePill(action: makeActive)
                            .disabled(!isEnabled)
                            .help(isEnabled ? "Switch the mouse to this profile" : "Connect the mouse to switch to this profile")
                    }
                }
                if hasPendingChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                        .help("Has changes that are not on the mouse")
                }
            }
            .contentShape(.rect)
        } icon: {
            Image(systemName: preset.symbol)
        }
        .onHover { isHovered = $0 }
        .accessibilityActions {
            if case .inactive(true, let makeActive) = activity {
                Button("Make Active", action: makeActive)
            }
        }
    }
}

private struct EmptySlotRow: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.tertiary)
            .selectionDisabled()
    }
}

private struct DeviceStatus: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(
                        colors: [Color(white: 0.56), Color(white: 0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("Zelotes C-18")
                    .font(.callout.weight(.medium))
                HStack(spacing: 5) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(isConnected ? "Connected" : "Not Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
