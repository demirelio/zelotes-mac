import SwiftUI

/// A button that opens an editor in a popover. `label` is told whether the pointer is over the button.
struct PopoverRowButton<Label: View>: View {
    let open: () -> Void
    @ViewBuilder let label: (_ isHovered: Bool) -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            label(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

/// The value at a row's trailing edge, drawn like a pop-up button: the value, a pair of chevrons, and a rounded
/// highlight while the pointer is over the row or `editor` is open below it.
struct PopoverValueLabel<Value: View, Editor: View>: View {
    let isHovered: Bool
    @Binding var isPresented: Bool
    @ViewBuilder let value: Value
    @ViewBuilder let editor: Editor

    private let inset: CGFloat = 7

    var body: some View {
        HStack(spacing: 7) {
            value
            Image(systemName: "chevron.up.chevron.down")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, inset)
        .frame(minHeight: 26)
        .background(
            Color.primary.opacity(isHovered || isPresented ? 0.07 : 0),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .contentShape(.rect)
        .padding(.trailing, -inset)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            editor
        }
    }
}
