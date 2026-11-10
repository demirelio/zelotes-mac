import SwiftUI
import ZelotesKit

struct ActionEditor: View {
    @Binding var action: ButtonAction

    var body: some View {
        Form {
            Picker("Action", selection: kind) {
                ForEach(ActionKind.allCases.filter { $0 != .disabled }, id: \.self) { kind in
                    Label(kind.title, systemImage: kind.symbol).tag(kind)
                }
                Divider()
                Label(ActionKind.disabled.title, systemImage: ActionKind.disabled.symbol).tag(ActionKind.disabled)
            }
            detail
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var detail: some View {
        switch action {
        case .disabled:
            EmptyView()
        case .click(let click):
            ChoicePicker(label: "Click", selection: bound(click) { .click($0) }, title: \.title)
        case .key(let stroke):
            KeyStrokeFields(stroke: bound(stroke) { .key($0) })
        case .windowNavigation(let navigation):
            WindowNavigationFields(navigation: bound(navigation) { .windowNavigation($0) })
        case .media(let key):
            ChoicePicker(label: "Control", selection: bound(key) { .media($0) }, title: \.title)
        case .dpi(let step):
            ChoicePicker(label: "Stage", selection: bound(step) { .dpi($0) }, title: \.dpiOptionTitle)
        case .profile(let step):
            ChoicePicker(label: "Profile", selection: bound(step) { .profile($0) }, title: \.profileOptionTitle)
        case .multiClick(let multiClick):
            MultiClickFields(multiClick: bound(multiClick) { .multiClick($0) })
        }
    }

    private var kind: Binding<ActionKind> {
        Binding(
            get: { action.kind },
            set: { newKind in
                if newKind != action.kind {
                    action = newKind.initialAction
                }
            }
        )
    }

    private func bound<Value>(_ value: Value, _ wrap: @escaping (Value) -> ButtonAction) -> Binding<Value> {
        Binding(get: { value }, set: { action = wrap($0) })
    }
}

private struct ChoicePicker<Choice: CaseIterable & Hashable>: View {
    let label: String
    @Binding var selection: Choice
    let title: (Choice) -> String

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(Array(Choice.allCases), id: \.self) { choice in
                Text(title(choice)).tag(choice)
            }
        }
    }
}

private struct KeyStrokeFields: View {
    @Binding var stroke: KeyStroke

    var body: some View {
        LabeledContent("Modifiers") {
            HStack(spacing: 5) {
                ForEach(ModifierKey.allCases, id: \.self) { key in
                    Toggle(key.symbol, isOn: isHeld(key.modifier))
                        .toggleStyle(KeycapToggleStyle())
                        .help(key.name)
                }
            }
        }
        Picker("Key", selection: $stroke.key) {
            ForEach(KeyboardKey.groups) { group in
                Section(group.title) {
                    ForEach(group.keys, id: \.self) { key in
                        Text(key.name).tag(key)
                    }
                }
            }
        }
    }

    private func isHeld(_ modifier: KeyModifiers) -> Binding<Bool> {
        Binding(
            get: { stroke.modifiers.contains(modifier) },
            set: { isOn in
                if isOn {
                    stroke.modifiers.insert(modifier)
                } else {
                    stroke.modifiers.remove(modifier)
                }
            }
        )
    }
}

private struct WindowNavigationFields: View {
    @Binding var navigation: WindowNavigation

    var body: some View {
        Section {
            Picker("System", selection: system) {
                ForEach(DesktopSystem.allCases, id: \.self) { system in
                    Text(system.title).tag(system)
                }
            }
            .pickerStyle(.segmented)
            Picker("Command", selection: $navigation.command) {
                ForEach(commands, id: \.self) { command in
                    Text(command.title(on: navigation.system)).tag(command)
                }
            }
            if let stroke = navigation.keyStroke {
                LabeledContent("Shortcut") {
                    Keycaps(legends: stroke.keycapLegends(on: navigation.system))
                }
            }
        } footer: {
            Text(navigation.system.shortcutNote)
        }
    }

    private var commands: [WindowCommand] {
        WindowCommand.allCases.filter { $0.keyStroke(on: navigation.system) != nil }
    }

    private var system: Binding<DesktopSystem> {
        Binding(
            get: { navigation.system },
            set: { navigation = navigation.switched(to: $0) }
        )
    }
}

private struct KeycapToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(width: 34, height: 28)
                .foregroundStyle(configuration.isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .background(
                    configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

private struct MultiClickFields: View {
    @Binding var multiClick: MultiClick

    var body: some View {
        LabeledContent("Clicks") {
            Text("\(multiClick.times)")
                .monospacedDigit()
            Stepper("Clicks", value: $multiClick.times, in: 2...50)
                .labelsHidden()
        }
        LabeledContent("Interval") {
            Text("\(multiClick.delayMilliseconds) ms")
                .monospacedDigit()
            Stepper(
                "Interval",
                value: $multiClick.delayMilliseconds,
                in: 1...MultiClick.maximumDelayMilliseconds
            )
            .labelsHidden()
        }
    }
}
