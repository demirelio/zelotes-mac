import SwiftUI

/// The capsule that marks the active one of several choices, such as a DPI stage or a mouse profile.
struct ActivePill: View {
    @Environment(\.backgroundProminence) private var backgroundProminence

    var body: some View {
        Text("Active")
            .pill(
                onSelection: backgroundProminence == .increased,
                foreground: AnyShapeStyle(.tint),
                background: AnyShapeStyle(.tint.opacity(0.15))
            )
    }
}

/// Sits where `ActivePill` would, on a choice that is not active, and makes it the active one.
struct MakeActivePill: View {
    let action: () -> Void
    @Environment(\.backgroundProminence) private var backgroundProminence

    var body: some View {
        Button(action: action) {
            Text("Make Active")
                .pill(
                    onSelection: backgroundProminence == .increased,
                    foreground: AnyShapeStyle(.secondary),
                    background: AnyShapeStyle(.quaternary)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension Text {
    /// On a selected row the tint would vanish into the selection, so the pill turns white there.
    func pill(onSelection: Bool, foreground: AnyShapeStyle, background: AnyShapeStyle) -> some View {
        font(.caption.weight(.semibold))
            .foregroundStyle(onSelection ? AnyShapeStyle(.white) : foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(onSelection ? AnyShapeStyle(.white.opacity(0.22)) : background, in: Capsule())
            .fixedSize()
            .layoutPriority(1)
    }
}
