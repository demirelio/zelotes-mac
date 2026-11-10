public enum DesktopSystem: String, CaseIterable, Codable, Sendable {
    case macOS
    case windows
    case linux
}

public enum WindowCommand: String, CaseIterable, Codable, Sendable {
    case previousDesktop
    case nextDesktop
    /// Mission Control on macOS, Task View on Windows, the overview on Linux.
    case allWindows
    /// The windows of the front app. Only macOS has a shortcut for it.
    case appWindows
    case showDesktop
    case switchApp

    /// The shortcut `system` gives this command out of the box, or `nil` when it has none.
    /// Linux means GNOME, whose shortcuts Ubuntu and Fedora ship.
    public func keyStroke(on system: DesktopSystem) -> KeyStroke? {
        switch (system, self) {
        case (.macOS, .previousDesktop): KeyStroke(modifiers: .control, key: .leftArrow)
        case (.macOS, .nextDesktop): KeyStroke(modifiers: .control, key: .rightArrow)
        case (.macOS, .allWindows): KeyStroke(modifiers: .control, key: .upArrow)
        case (.macOS, .appWindows): KeyStroke(modifiers: .control, key: .downArrow)
        case (.macOS, .showDesktop): KeyStroke(key: .f11)
        case (.macOS, .switchApp): KeyStroke(modifiers: .command, key: .tab)
        case (.windows, .previousDesktop): KeyStroke(modifiers: [.control, .command], key: .leftArrow)
        case (.windows, .nextDesktop): KeyStroke(modifiers: [.control, .command], key: .rightArrow)
        case (.windows, .allWindows): KeyStroke(modifiers: .command, key: .tab)
        case (.windows, .showDesktop): KeyStroke(modifiers: .command, key: .d)
        case (.windows, .switchApp): KeyStroke(modifiers: .option, key: .tab)
        case (.linux, .previousDesktop): KeyStroke(modifiers: [.control, .option], key: .leftArrow)
        case (.linux, .nextDesktop): KeyStroke(modifiers: [.control, .option], key: .rightArrow)
        case (.linux, .allWindows): KeyStroke(modifiers: .command, key: .s)
        case (.linux, .showDesktop): KeyStroke(modifiers: .command, key: .d)
        case (.linux, .switchApp): KeyStroke(modifiers: .option, key: .tab)
        case (.windows, .appWindows), (.linux, .appWindows): nil
        }
    }
}

/// The mouse can only press keys, so the command is sent as that system's default shortcut and stops working
/// if the shortcut is changed there.
public struct WindowNavigation: Equatable, Codable, Sendable {
    public var system: DesktopSystem
    public var command: WindowCommand

    public init(system: DesktopSystem, command: WindowCommand) {
        self.system = system
        self.command = command
    }

    public var keyStroke: KeyStroke? {
        command.keyStroke(on: system)
    }

    /// The same command on `system`, or that system's view of all windows when it lacks the command.
    public func switched(to system: DesktopSystem) -> WindowNavigation {
        WindowNavigation(system: system, command: command.keyStroke(on: system) == nil ? .allWindows : command)
    }
}
