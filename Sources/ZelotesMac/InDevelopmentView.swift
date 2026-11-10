import SwiftUI

/// Stands in for a part of the app that has a place in the layout but is not built yet.
struct InDevelopmentView: View {
    let title: String
    let symbol: String
    let summary: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(summary)
        } actions: {
            Text("In Development")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MacrosPage: View {
    var body: some View {
        InDevelopmentView(
            title: "Macros",
            symbol: "record.circle",
            summary: "Record a sequence of keystrokes once, then assign it to any button in any preset."
        )
    }
}
