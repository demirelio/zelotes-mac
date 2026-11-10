import ZelotesKit

enum ActionKind: CaseIterable {
    case click
    case key
    case windowNavigation
    case media
    case dpi
    case profile
    case multiClick
    case disabled

    var title: String {
        switch self {
        case .click: "Mouse Click"
        case .key: "Keyboard Shortcut"
        case .windowNavigation: "Window Navigation"
        case .media: "Media"
        case .dpi: "DPI Stage"
        case .profile: "Mouse Profile"
        case .multiClick: "Multi-Click"
        case .disabled: "Off"
        }
    }

    var symbol: String {
        switch self {
        case .click: "cursorarrow.click"
        case .key: "keyboard"
        case .windowNavigation: "rectangle.3.group"
        case .media: "playpause"
        case .dpi: "gauge.with.needle"
        case .profile: "square.stack"
        case .multiClick: "cursorarrow.click.2"
        case .disabled: "nosign"
        }
    }

    var initialAction: ButtonAction {
        switch self {
        case .click: .click(.left)
        case .key: .key(KeyStroke(key: .space))
        case .windowNavigation: .windowNavigation(WindowNavigation(system: .macOS, command: .allWindows))
        case .media: .media(.playPause)
        case .dpi: .dpi(.cycle)
        case .profile: .profile(.cycle)
        case .multiClick: .multiClick(.doubleClick)
        case .disabled: .disabled
        }
    }
}

extension ButtonAction {
    var kind: ActionKind {
        switch self {
        case .click: .click
        case .key: .key
        case .windowNavigation: .windowNavigation
        case .media: .media
        case .dpi: .dpi
        case .profile: .profile
        case .multiClick: .multiClick
        case .disabled: .disabled
        }
    }
}
