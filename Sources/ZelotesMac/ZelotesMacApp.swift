import SwiftUI

@main
struct ZelotesMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Zelotes C-18", id: "presets") {
            ContentView(model: appDelegate.model)
        }
        .defaultSize(width: 1105, height: 726)
        .windowResizability(.contentMinSize)
        .commands {
            PresetCommands(model: appDelegate.model)
        }

        Settings {
            SettingsView()
        }
    }
}

private struct PresetCommands: Commands {
    let model: MappingModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Preset") { model.addPreset() }
                .keyboardShortcut("n")
            Button("Duplicate Preset") { model.duplicatePreset(model.selectedPresetID) }
                .keyboardShortcut("d")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.save() }
                .keyboardShortcut("s")
                .disabled(!model.hasUnsavedChanges)
            Button("Discard Changes") { model.discardChanges() }
                .disabled(!model.hasUnsavedChanges)
        }
        CommandGroup(before: .sidebar) {
            Button("Buttons") { model.presetPage = .buttons }
                .keyboardShortcut("1")
            Button("DPI") { model.presetPage = .dpi }
                .keyboardShortcut("2")
            Button("Lighting") { model.presetPage = .lighting }
                .keyboardShortcut("3")
            Button("Pointer") { model.presetPage = .pointer }
                .keyboardShortcut("4")
            Divider()
        }
        CommandMenu("Mouse") {
            Button("Update Mouse Now") { model.updateMouse() }
                .keyboardShortcut(.return)
                .disabled(!model.canUpdateMouse)
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = MappingModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppearancePreference.stored.apply()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model.refreshPointerAgentState()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.hasUnsavedChanges {
            switch askToSave() {
            case .alertFirstButtonReturn: model.save()
            case .alertThirdButtonReturn: model.discardChanges()
            default: return .terminateCancel
            }
        }
        Task {
            await model.waitForMouse()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func askToSave() -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = UnsavedChangesPrompt.title(for: model.presetDisplayName)
        alert.informativeText = UnsavedChangesPrompt.message
        alert.addButton(withTitle: UnsavedChangesPrompt.save)
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: UnsavedChangesPrompt.discard).hasDestructiveAction = true
        return alert.runModal()
    }
}
