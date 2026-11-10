import SwiftUI
import ZelotesKit

struct AssignmentRow: View {
    let title: String
    @Binding var action: ButtonAction
    @State private var isEditing = false

    var body: some View {
        LabeledContent(title) {
            PopoverRowButton(open: { isEditing = true }) { isHovered in
                PopoverValueLabel(isHovered: isHovered, isPresented: $isEditing) {
                    ActionSummary(action: action)
                } editor: {
                    ActionEditor(action: $action)
                }
            }
            .accessibilityLabel("Change what \(title) does")
        }
    }
}

struct ActionSummary: View {
    let action: ButtonAction

    var body: some View {
        switch action {
        case .disabled:
            Text("Off")
                .foregroundStyle(.tertiary)
        case .click(let click):
            Text(click.title)
                .foregroundStyle(.secondary)
        case .key(let stroke):
            Keycaps(legends: stroke.keycapLegends())
        case .windowNavigation(let navigation):
            Text(navigation.summary)
                .foregroundStyle(.secondary)
        case .media(let key):
            Text(key.title)
                .foregroundStyle(.secondary)
        case .dpi(let step):
            Text(step.dpiTitle)
                .foregroundStyle(.secondary)
        case .profile(let step):
            Text(step.profileTitle)
                .foregroundStyle(.secondary)
        case .multiClick(let multiClick):
            Text("\(multiClick.times) Clicks · \(multiClick.delayMilliseconds) ms")
                .foregroundStyle(.secondary)
        }
    }
}

struct Keycaps: View {
    let legends: [String]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(legends, id: \.self) { legend in
                Text(legend)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .padding(.horizontal, 6)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(legends.joined(separator: " "))
    }
}
