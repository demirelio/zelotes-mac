/// The eleven remappable buttons, numbered as in the vendor's Windows software.
public enum MouseButton: Int, CaseIterable, Sendable {
    case leftButton = 1
    case rightButton
    case wheelPress
    case thumbFront
    case thumbRear
    case dpiButton
    case joystickUp
    case joystickDown
    case joystickLeft
    case joystickRight
    case joystickPress

    var tableOffset: Int {
        switch self {
        case .leftButton: 0
        case .rightButton: 4
        case .wheelPress: 8
        case .thumbFront: 12
        case .thumbRear: 16
        case .dpiButton: 20
        case .joystickPress: 24
        case .joystickUp: 32
        case .joystickDown: 36
        case .joystickLeft: 40
        case .joystickRight: 44
        }
    }
}
