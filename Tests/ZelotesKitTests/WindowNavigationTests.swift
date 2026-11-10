import Testing
import ZelotesKit

@Suite struct WindowNavigationTests {
    @Test(arguments: [
        (DesktopSystem.macOS, WindowCommand.previousDesktop, KeyStroke(modifiers: .control, key: .leftArrow) as KeyStroke?),
        (.macOS, .nextDesktop, KeyStroke(modifiers: .control, key: .rightArrow)),
        (.macOS, .allWindows, KeyStroke(modifiers: .control, key: .upArrow)),
        (.macOS, .appWindows, KeyStroke(modifiers: .control, key: .downArrow)),
        (.macOS, .showDesktop, KeyStroke(key: .f11)),
        (.macOS, .switchApp, KeyStroke(modifiers: .command, key: .tab)),
        (.windows, .previousDesktop, KeyStroke(modifiers: [.control, .command], key: .leftArrow)),
        (.windows, .nextDesktop, KeyStroke(modifiers: [.control, .command], key: .rightArrow)),
        (.windows, .allWindows, KeyStroke(modifiers: .command, key: .tab)),
        (.windows, .appWindows, nil),
        (.windows, .showDesktop, KeyStroke(modifiers: .command, key: .d)),
        (.windows, .switchApp, KeyStroke(modifiers: .option, key: .tab)),
        (.linux, .previousDesktop, KeyStroke(modifiers: [.control, .option], key: .leftArrow)),
        (.linux, .nextDesktop, KeyStroke(modifiers: [.control, .option], key: .rightArrow)),
        (.linux, .allWindows, KeyStroke(modifiers: .command, key: .s)),
        (.linux, .appWindows, nil),
        (.linux, .showDesktop, KeyStroke(modifiers: .command, key: .d)),
        (.linux, .switchApp, KeyStroke(modifiers: .option, key: .tab)),
    ])
    func eachSystemHasItsOwnDefaultShortcut(system: DesktopSystem, command: WindowCommand, shortcut: KeyStroke?) {
        #expect(command.keyStroke(on: system) == shortcut)
    }

    @Test(arguments: DesktopSystem.allCases)
    func noTwoCommandsShareAShortcut(on system: DesktopSystem) {
        let shortcuts = WindowCommand.allCases.compactMap { $0.keyStroke(on: system) }
        let distinct = Set(shortcuts.map { [$0.modifiers.rawValue, $0.key.usage] })

        #expect(distinct.count == shortcuts.count)
    }

    @Test func aNavigationPressesTheShortcutOfItsSystem() {
        let navigation = WindowNavigation(system: .windows, command: .showDesktop)

        #expect(navigation.keyStroke == KeyStroke(modifiers: .command, key: .d))
    }

    @Test func switchingSystemsKeepsTheCommand() {
        let navigation = WindowNavigation(system: .macOS, command: .nextDesktop)

        #expect(navigation.switched(to: .linux) == WindowNavigation(system: .linux, command: .nextDesktop))
    }

    @Test func switchingToASystemWithoutTheCommandFallsBackToItsViewOfAllWindows() {
        let navigation = WindowNavigation(system: .macOS, command: .appWindows)

        #expect(navigation.switched(to: .windows) == WindowNavigation(system: .windows, command: .allWindows))
        #expect(navigation.switched(to: .linux) == WindowNavigation(system: .linux, command: .allWindows))
        #expect(navigation.switched(to: .macOS) == navigation)
    }
}
