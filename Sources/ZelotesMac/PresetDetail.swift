import SwiftUI
import ZelotesKit

struct PresetDetail: View {
    @Bindable var model: MappingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PresetHeader(model: model)
                .padding(.horizontal, 30)
                .padding(.top, 18)
            switch model.presetPage {
            case .buttons:
                ButtonsPage(model: model)
            case .dpi:
                DPIPage(
                    dpi: $model.dpi,
                    stageNames: $model.stageNames,
                    hasDPIStageButton: model.hasDPIStageButton,
                    chooseStage: { model.chooseActiveStage($0) },
                    showButtons: { model.presetPage = .buttons }
                )
            case .lighting:
                LightingPage(lighting: $model.lighting)
            case .pointer:
                PointerPage(
                    pointer: $model.pointer,
                    status: model.pointerStatus,
                    agentState: model.pointerAgentState,
                    canMakeProfileActive: model.canMakeProfileActive,
                    makeActive: { model.makeActive($0) }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Section", selection: $model.presetPage) {
                    ForEach(PresetPage.allCases, id: \.self) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
            }
            ToolbarSpacer(.flexible)
            ToolbarItem {
                Menu("More", systemImage: "ellipsis") {
                    PresetActions(model: model, presetID: model.selectedPresetID)
                }
                .menuIndicator(.hidden)
                .help("More actions for this preset")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button("Save") { model.save() }
                    .buttonStyle(.glassProminent)
                    .disabled(!model.hasUnsavedChanges)
                    .help("Save the changes to this preset")
            }
        }
    }
}

private struct ButtonsPage: View {
    @Bindable var model: MappingModel
    @AppStorage(LayoutPreference.compactKey) private var usesCompactLayout = false

    var body: some View {
        if usesCompactLayout {
            ButtonList(model: model)
        } else {
            MouseDiagramPage(model: model)
        }
    }
}

private struct ButtonList: View {
    @Bindable var model: MappingModel

    var body: some View {
        Form {
            ForEach(ButtonGroup.allCases, id: \.self) { group in
                Section(group.title) {
                    ForEach(group.buttons, id: \.self) { button in
                        AssignmentRow(title: button.title, action: $model.table[button])
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PresetHeader: View {
    @Bindable var model: MappingModel
    @FocusState private var isNameFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            PresetIconButton(symbol: $model.presetSymbol)
            VStack(alignment: .leading, spacing: 4) {
                name
                    .font(.largeTitle.weight(.bold))
                status
                    .font(.callout)
                    .animation(.snappy, value: model.writeState)
                    .animation(.snappy, value: model.mouseState)
                    .animation(.snappy, value: model.hasUnsavedChanges)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var name: some View {
        if model.isRenamingPreset {
            TextField("Preset Name", text: $model.presetName)
                .labelsHidden()
                .textFieldStyle(.plain)
                .focused($isNameFocused)
                .onSubmit { model.isRenamingPreset = false }
                .onAppear { isNameFocused = true }
                .onChange(of: isNameFocused) { _, isFocused in
                    if !isFocused {
                        model.isRenamingPreset = false
                    }
                }
        } else {
            Text(model.presetDisplayName)
                .lineLimit(1)
                .contentShape(.rect)
                .onTapGesture { model.isRenamingPreset = true }
                .help("Click to rename")
        }
    }

    @ViewBuilder private var status: some View {
        if model.hasUnsavedChanges {
            Label("Unsaved changes", systemImage: "pencil.circle.fill")
                .foregroundStyle(.orange)
        } else {
            savedStatus
        }
    }

    @ViewBuilder private var savedStatus: some View {
        switch model.writeState {
        case .failed(let reason):
            HStack(spacing: 10) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                // A retry writes held-back buttons too, so it needs the same consent as Update Anyway.
                updateButton(model.mouseState.isHeldWithoutLeftClick ? "Update Anyway" : "Try Again")
            }
        case .writing:
            Label("Updating the mouse…", systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case .idle:
            switch model.mouseState {
            case .onMouse(let profile):
                Label("On the mouse in Profile \(profile.rawValue)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .changesPending(let profile):
                HStack(spacing: 10) {
                    Label(
                        model.isMouseConnected
                            ? "Changes not in Profile \(profile.rawValue) yet"
                            : "Connect the mouse to update Profile \(profile.rawValue)",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .foregroundStyle(.orange)
                    updateButton("Update")
                }
            case .heldWithoutLeftClick:
                HStack(spacing: 10) {
                    Label("Not sent to the mouse: no button is set to Left Click", systemImage: "hand.raised.fill")
                        .foregroundStyle(.orange)
                    updateButton("Update Anyway")
                }
            case .inReserve:
                Label("In reserve. Drag it onto a profile to use it on the mouse.", systemImage: "tray")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func updateButton(_ title: String) -> some View {
        if model.canUpdateMouse {
            Button(title) { model.updateMouse() }
                .buttonStyle(.link)
        }
    }
}
