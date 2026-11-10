import SwiftUI

struct ContentView: View {
    @Bindable var model: MappingModel
    @FocusState private var isSidebarFocused: Bool

    var body: some View {
        NavigationSplitView {
            PresetSidebar(model: model)
                .focused($isSidebarFocused)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } detail: {
            if model.isShowingMacros {
                MacrosPage()
            } else {
                PresetDetail(model: model)
            }
        }
        .toolbar(removing: .title)
        .defaultFocus($isSidebarFocused, true)
        .frame(minWidth: 780, minHeight: 600)
        .confirmationDialog(
            model.pendingConfirmation?.title ?? "",
            isPresented: isConfirming,
            presenting: model.pendingConfirmation
        ) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) { model.carryOut(confirmation) }
        } message: { confirmation in
            Text(confirmation.message)
        }
        .alert(
            UnsavedChangesPrompt.title(for: model.presetDisplayName),
            isPresented: isAskingToSave,
            presenting: model.intentAwaitingSaveDecision
        ) { intent in
            Button(UnsavedChangesPrompt.save) { model.resolve(intent, saving: true) }
            Button(UnsavedChangesPrompt.discard, role: .destructive) { model.resolve(intent, saving: false) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(UnsavedChangesPrompt.message)
        }
        .dismissalConfirmationDialog(
            UnsavedChangesPrompt.title(for: model.presetDisplayName),
            shouldPresent: model.hasUnsavedChanges
        ) {
            Button(UnsavedChangesPrompt.save) { model.save() }
            Button(UnsavedChangesPrompt.discard, role: .destructive) { model.discardChanges() }
        } message: {
            Text(UnsavedChangesPrompt.message)
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(
            get: { model.pendingConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    model.pendingConfirmation = nil
                }
            }
        )
    }

    private var isAskingToSave: Binding<Bool> {
        Binding(
            get: { model.intentAwaitingSaveDecision != nil },
            set: { isPresented in
                if !isPresented {
                    model.intentAwaitingSaveDecision = nil
                }
            }
        )
    }
}

/// The wording of the question asked before unsaved edits would be lost, shared by every place that asks it.
enum UnsavedChangesPrompt {
    static let message = "Your changes will be lost if you don’t save them."
    static let save = "Save"
    static let discard = "Discard Changes"

    static func title(for presetName: String) -> String {
        "Do you want to save the changes to “\(presetName)”?"
    }
}

private extension MappingModel.Confirmation {
    var title: String {
        switch self {
        case .deletePreset(let preset): "Delete “\(preset.displayName)”?"
        case .assignWithoutLeftClick(let preset, _): "“\(preset.displayName)” has no Left Click button"
        }
    }

    var message: String {
        switch self {
        case .deletePreset:
            "The preset is removed from this Mac. What is already on the mouse stays as it is."
        case .assignWithoutLeftClick(_, let profile):
            "With it in Profile \(profile.rawValue), you would have to click with the trackpad or another mouse "
                + "until you change the mapping."
        }
    }

    var actionTitle: String {
        switch self {
        case .deletePreset: "Delete"
        case .assignWithoutLeftClick: "Use Anyway"
        }
    }
}
