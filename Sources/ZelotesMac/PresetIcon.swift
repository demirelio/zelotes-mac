import SwiftUI

/// The preset's icon as a tile; clicking it opens the symbol picker.
struct PresetIconButton: View {
    @Binding var symbol: String
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 54, height: 54)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 19, height: 19)
                        .background(.background, in: Circle())
                        .overlay(Circle().strokeBorder(.quaternary))
                        .offset(x: 5, y: 5)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Change the icon")
        .accessibilityLabel("Change the icon")
        .popover(isPresented: $isPicking, arrowEdge: .bottom) {
            SymbolPicker(selection: $symbol) { isPicking = false }
        }
    }
}

private struct SymbolPicker: View {
    @Binding var selection: String
    let onPick: () -> Void

    private static let columns = Array(repeating: GridItem(.fixed(36), spacing: 6), count: 8)

    private static let symbols = [
        "computermouse.fill", "keyboard.fill", "desktopcomputer", "laptopcomputer", "display",
        "gamecontroller.fill", "headphones", "tv.fill",
        "briefcase.fill", "doc.text.fill", "folder.fill", "tray.full.fill", "envelope.fill",
        "calendar", "chart.bar.fill", "terminal.fill",
        "chevron.left.forwardslash.chevron.right", "hammer.fill", "wrench.and.screwdriver.fill",
        "gearshape.fill", "slider.horizontal.3", "command", "cursorarrow.rays", "hand.tap.fill",
        "paintbrush.fill", "paintpalette.fill", "pencil.tip", "scissors", "camera.fill",
        "photo.fill", "film.fill", "video.fill",
        "music.note", "waveform", "mic.fill", "cube.fill", "wand.and.stars", "sparkles",
        "globe", "safari.fill",
        "message.fill", "person.fill", "person.2.fill", "house.fill", "book.fill",
        "graduationcap.fill", "cart.fill", "creditcard.fill",
        "flag.checkered", "target", "scope", "bolt.fill", "flame.fill", "star.fill",
        "heart.fill", "crown.fill",
        "trophy.fill", "dice.fill", "puzzlepiece.fill", "moon.fill", "sun.max.fill",
        "leaf.fill", "airplane", "car.fill",
        "cup.and.saucer.fill", "bed.double.fill", "figure.walk", "lock.fill", "eye.fill",
        "clock.fill", "map.fill", "tag.fill",
    ].filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(Self.symbols, id: \.self) { symbol in
                Button {
                    selection = symbol
                    onPick()
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(symbol == selection ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .frame(width: 36, height: 36)
                        .background(
                            symbol == selection ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary.opacity(0.5)),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}
