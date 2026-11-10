import AppKit
import SwiftUI

enum LayoutPreference {
    static let compactKey = "usesCompactLayout"
}

/// Light or dark for the whole app, or whatever System Settings › Appearance says.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    static let key = "appearance"

    static var stored: AppearancePreference {
        UserDefaults.standard.string(forKey: key).flatMap(AppearancePreference.init) ?? .system
    }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Set on the application, so the Settings window and alerts follow too.
    @MainActor func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// The Settings window: one toolbar tab per pane, so a new group of settings is a new `Tab`.
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings()
            }
        }
        .frame(width: 500)
    }
}

private struct GeneralSettings: View {
    @AppStorage(LayoutPreference.compactKey) private var usesCompactLayout = false
    @AppStorage(AppearancePreference.key) private var appearance = AppearancePreference.system

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases, id: \.self) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .onChange(of: appearance) { _, appearance in
                    appearance.apply()
                }
            }
            Section {
                Picker("Layout", selection: $usesCompactLayout) {
                    Text("Mouse Photo").tag(false)
                    Text("Compact List").tag(true)
                }
            } header: {
                Text("Buttons")
            } footer: {
                Text("Mouse Photo shows the buttons beside a photo of the mouse. Compact List shows them as one list.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}
