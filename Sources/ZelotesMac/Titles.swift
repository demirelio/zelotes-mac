import ZelotesKit

/// The aspects of a preset, switched from the toolbar.
enum PresetPage: CaseIterable {
    case buttons
    case dpi
    case lighting
    case pointer

    var title: String {
        switch self {
        case .buttons: "Buttons"
        case .dpi: "DPI"
        case .lighting: "Lighting"
        case .pointer: "Pointer"
        }
    }
}

extension LightingEffect {
    var title: String {
        switch self {
        case .steady: "Steady"
        case .breathing: "Breathing"
        case .neon: "Neon"
        case .wave: "Wave"
        case .flowing: "Flowing"
        case .off: "Off"
        }
    }
}

extension LightColor {
    var title: String {
        switch self {
        case .red: "Red"
        case .green: "Green"
        case .blue: "Blue"
        case .yellow: "Yellow"
        case .magenta: "Magenta"
        case .cyan: "Cyan"
        case .white: "White"
        }
    }
}

extension LightBrightness {
    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

extension LightSpeed {
    var title: String {
        switch self {
        case .slow: "Slow"
        case .medium: "Medium"
        case .fast: "Fast"
        }
    }
}

extension PointerAcceleration {
    var title: String {
        switch self {
        case .macOS: "macOS"
        case .windows: "Windows"
        case .none: "None"
        case .custom: "Custom"
        }
    }
}

enum ButtonGroup: CaseIterable {
    case finger
    case thumb
    case joystick

    var title: String {
        switch self {
        case .finger: "Finger Buttons"
        case .thumb: "Thumb Buttons"
        case .joystick: "Joystick"
        }
    }

    var buttons: [MouseButton] {
        switch self {
        case .finger: [.leftButton, .rightButton, .wheelPress, .dpiButton]
        case .thumb: [.thumbFront, .thumbRear]
        case .joystick: [.joystickPress, .joystickUp, .joystickRight, .joystickDown, .joystickLeft]
        }
    }
}

extension MouseButton {
    var title: String {
        switch self {
        case .leftButton: "Left Button"
        case .rightButton: "Right Button"
        case .wheelPress: "Wheel Button"
        case .dpiButton: "DPI Button"
        case .thumbFront: "Front Button"
        case .thumbRear: "Rear Button"
        case .joystickUp: "Up"
        case .joystickDown: "Down"
        case .joystickLeft: "Left"
        case .joystickRight: "Right"
        case .joystickPress: "Press"
        }
    }
}

extension MouseClick {
    var title: String {
        switch self {
        case .left: "Left Click"
        case .right: "Right Click"
        case .middle: "Middle Click"
        case .back: "Back"
        case .forward: "Forward"
        }
    }
}

extension MediaKey {
    var title: String {
        switch self {
        case .playPause: "Play/Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .stop: "Stop"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Mute"
        }
    }
}

extension StepDirection {
    var dpiTitle: String {
        switch self {
        case .up: "Next DPI Stage"
        case .down: "Previous DPI Stage"
        case .cycle: "Cycle DPI Stages"
        }
    }

    var dpiOptionTitle: String {
        switch self {
        case .up: "Next"
        case .down: "Previous"
        case .cycle: "Cycle"
        }
    }

    var profileTitle: String {
        switch self {
        case .up: "Next Profile"
        case .down: "Previous Profile"
        case .cycle: "Switch Profile"
        }
    }

    var profileOptionTitle: String {
        switch self {
        case .up: "Next"
        case .down: "Previous"
        case .cycle: "Switch"
        }
    }
}

extension DesktopSystem {
    var title: String {
        switch self {
        case .macOS: "macOS"
        case .windows: "Windows"
        case .linux: "Linux"
        }
    }

    /// What a window command relies on, for the note under its settings.
    var shortcutNote: String {
        switch self {
        case .macOS:
            "The mouse presses the shortcut macOS uses by default. It stops working if that shortcut "
                + "is changed in System Settings › Keyboard › Keyboard Shortcuts."
        case .windows:
            "The mouse presses the shortcut Windows uses by default."
        case .linux:
            "The mouse presses the shortcut GNOME uses by default. Other desktops may use a different one."
        }
    }
}

extension WindowCommand {
    /// What `system` calls this command.
    func title(on system: DesktopSystem) -> String {
        switch self {
        case .previousDesktop: system == .linux ? "Previous Workspace" : "Previous Desktop"
        case .nextDesktop: system == .linux ? "Next Workspace" : "Next Desktop"
        case .allWindows:
            switch system {
            case .macOS: "Mission Control"
            case .windows: "Task View"
            case .linux: "Overview"
            }
        case .appWindows: "App Exposé"
        case .showDesktop: "Show Desktop"
        case .switchApp: "Switch App"
        }
    }
}

extension WindowNavigation {
    /// The command's name, with the system when it is not this Mac's.
    var summary: String {
        let title = command.title(on: system)
        return system == .macOS ? title : "\(title) · \(system.title)"
    }
}

enum ModifierKey: CaseIterable {
    case control
    case option
    case shift
    case command

    var modifier: KeyModifiers {
        switch self {
        case .control: .control
        case .option: .option
        case .shift: .shift
        case .command: .command
        }
    }

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    var name: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        case .shift: "Shift"
        case .command: "Command"
        }
    }

    /// What the key is labelled on a keyboard made for `system`.
    func legend(on system: DesktopSystem) -> String {
        switch (system, self) {
        case (.macOS, _): symbol
        case (_, .control): "Ctrl"
        case (_, .option): "Alt"
        case (_, .shift): "Shift"
        case (.windows, .command): "Win"
        case (.linux, .command): "Super"
        }
    }
}

extension KeyStroke {
    /// The modifiers in the order macOS menus show them, followed by the key.
    func keycapLegends(on system: DesktopSystem = .macOS) -> [String] {
        ModifierKey.allCases.filter { modifiers.contains($0.modifier) }.map { $0.legend(on: system) }
            + [key.keycapLegend]
    }
}

extension KeyboardKey {
    private static let glyphsByName = [
        "Return": "↩", "Escape": "esc", "Delete": "⌫", "Forward Delete": "⌦", "Tab": "⇥",
        "Space": "space", "Home": "↖", "End": "↘", "Page Up": "⇞", "Page Down": "⇟",
    ]

    var keycapLegend: String {
        Self.glyphsByName[name] ?? name
    }
}
