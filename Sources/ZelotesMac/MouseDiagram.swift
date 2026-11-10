import SwiftUI
import ZelotesKit

/// The side of the mouse a photo shows.
enum MouseSide: CaseIterable, Hashable {
    /// Its photo is taken from the front, so the thumb controls are in sight too.
    case fingerSide
    case thumbSide

    var title: String {
        switch self {
        case .fingerSide: "Finger Side"
        case .thumbSide: "Thumb Side"
        }
    }

    var art: MouseArt {
        switch self {
        case .fingerSide: .fingerSide
        case .thumbSide: .thumbSide
        }
    }

    /// Each side turns in from its own flank, so a switch reads as the mouse turning around.
    fileprivate var transition: AnyTransition {
        let angle: Double = switch self {
        case .fingerSide: 80
        case .thumbSide: -80
        }
        return .modifier(active: Turn(angle: angle, isHidden: true), identity: Turn(angle: 0, isHidden: false))
    }
}

private struct Turn: ViewModifier {
    let angle: Double
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(isHidden ? 0.9 : 1)
            .opacity(isHidden ? 0 : 1)
    }
}

/// The buttons grouped beside a photo of the mouse, which turns to show the side being edited.
struct MouseDiagramPage: View {
    @Bindable var model: MappingModel
    @State private var activeButton: MouseButton?
    @State private var chosenSide = MouseSide.fingerSide
    @State private var shownSide = MouseSide.fingerSide
    @State private var returnToChosenSide: Task<Void, Never>?

    private static let turn = Animation.smooth(duration: 0.45)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                1,
                proxy.size.width / DiagramLayout.minimumSize.width,
                proxy.size.height / DiagramLayout.minimumSize.height
            )
            let size = CGSize(width: proxy.size.width / scale, height: proxy.size.height / scale)
            diagram(columnWidth: DiagramLayout.columnWidth(inWidth: size.width))
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func diagram(columnWidth: CGFloat) -> some View {
        let stacksValues = columnWidth < DiagramLayout.widthForOneLineRows
        return HStack(spacing: DiagramLayout.spacing) {
            section(.finger, stacksValues: stacksValues)
                .frame(width: columnWidth)
            VStack(spacing: 16) {
                photo
                sidePicker
            }
            VStack(spacing: 20) {
                section(.joystick, stacksValues: stacksValues)
                section(.thumb, stacksValues: stacksValues)
            }
            .frame(width: columnWidth)
        }
        .padding(DiagramLayout.padding)
        .overlayPreferenceValue(DiagramFrames.self) { frames in
            GeometryReader { proxy in
                leader(frames: frames, in: proxy)
            }
        }
    }

    private var photo: some View {
        ZStack {
            MouseArtView(
                art: shownSide.art,
                lit: activeButton.map { [$0.artElementID] } ?? [],
                pointerID: activeButton?.artPointerID
            )
            .id(shownSide)
            .transition(shownSide.transition)
        }
        .frame(maxWidth: DiagramLayout.largestPhoto.width, maxHeight: DiagramLayout.largestPhoto.height)
        .anchorPreference(key: DiagramFrames.self, value: .bounds) { [.photo: $0] }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidePicker: some View {
        Picker("View", selection: sideSelection) {
            ForEach(MouseSide.allCases, id: \.self) { side in
                Text(side.title).tag(side)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private func section(_ group: ButtonGroup, stacksValues: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.headline)
                .padding(.leading, DiagramLayout.rowInset)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(group.buttons.enumerated()), id: \.element) { index, button in
                    if index > 0 {
                        Divider()
                            .padding(.leading, DiagramLayout.rowInset)
                    }
                    DiagramRow(
                        title: button.title,
                        spokenTitle: button.spokenTitle,
                        symbol: button.directionSymbol,
                        action: $model.table[button],
                        stacksValue: stacksValues
                    ) { isActive in
                        setActive(isActive, button)
                    }
                    .anchorPreference(key: DiagramFrames.self, value: .bounds) { [.row(button): $0] }
                }
            }
            .background(Color.primary.opacity(0.05), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
        }
    }

    /// A line from the row being pointed at or edited to its button, when the photo on screen shows it.
    private func leader(frames: [DiagramItem: Anchor<CGRect>], in proxy: GeometryProxy) -> some View {
        ZStack {
            if let button = activeButton, let rowFrame = frames[.row(button)], let photoFrame = frames[.photo],
               let spot = shownSide.art.position(ofSpot: button.artSpotID, fittedIn: proxy[photoFrame]) {
                let row = proxy[rowFrame]
                let start = CGPoint(x: row.midX < spot.x ? row.maxX : row.minX, y: row.midY)
                Group {
                    LeaderLine(from: start, to: spot)
                        .stroke(.tint, lineWidth: 1)
                    Circle()
                        .fill(.tint)
                        .frame(width: 7, height: 7)
                        .position(spot)
                }
                .id(button)
                .transition(.opacity)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: activeButton)
    }

    private var sideSelection: Binding<MouseSide> {
        Binding(
            get: { shownSide },
            set: { side in
                returnToChosenSide?.cancel()
                chosenSide = side
                withAnimation(Self.turn) { shownSide = side }
            }
        )
    }

    private func setActive(_ isActive: Bool, _ button: MouseButton) {
        returnToChosenSide?.cancel()
        if isActive {
            activeButton = button
            withAnimation(Self.turn) { shownSide = button.clearestSide }
        } else if activeButton == button {
            activeButton = nil
            returnToChosenSide = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                withAnimation(Self.turn) { shownSide = chosenSide }
            }
        }
    }
}

private enum DiagramItem: Hashable {
    case row(MouseButton)
    case photo
}

/// Where the rows and the photo ended up, so a leader line can join them.
private struct DiagramFrames: PreferenceKey {
    static var defaultValue: [DiagramItem: Anchor<CGRect>] { [:] }

    static func reduce(
        value: inout [DiagramItem: Anchor<CGRect>],
        nextValue: () -> [DiagramItem: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

private enum DiagramLayout {
    static let padding: CGFloat = 20
    static let spacing: CGFloat = 16
    static let rowInset: CGFloat = 12
    static let narrowestColumn: CGFloat = 196
    static let widestColumn: CGFloat = 280
    /// A column at least this wide holds a title and its assignment side by side.
    static let widthForOneLineRows: CGFloat = 258
    /// The columns widen only once the photo has this much width.
    static let preferredPhotoWidth: CGFloat = 240
    /// The photos are small; shown larger than this they turn soft.
    static let largestPhoto = CGSize(width: 380, height: 500)
    /// In a smaller space the page is scaled down instead of squeezed further.
    static let minimumSize = CGSize(width: 660, height: 520)

    static func columnWidth(inWidth width: CGFloat) -> CGFloat {
        let spare = width - 2 * padding - 2 * spacing - preferredPhotoWidth
        return min(widestColumn, max(narrowestColumn, spare / 2))
    }
}

private extension MouseButton {
    /// The id of this button's outline in the button maps.
    var artElementID: String {
        switch self {
        case .leftButton: "button-left"
        case .rightButton: "button-right"
        case .wheelPress: "button-wheel"
        case .dpiButton: "button-dpi"
        case .thumbFront: "button-thumb-front"
        case .thumbRear: "button-thumb-rear"
        case .joystickUp, .joystickDown, .joystickLeft, .joystickRight, .joystickPress: "joystick"
        }
    }

    var artSpotID: String {
        "spot-" + artElementID
    }

    /// The id of the pointer that tells this input apart from the others on the same outline.
    var artPointerID: String? {
        switch self {
        case .joystickUp: "joystick-up"
        case .joystickDown: "joystick-down"
        case .joystickLeft: "joystick-left"
        case .joystickRight: "joystick-right"
        case .joystickPress: "joystick-press"
        case .leftButton, .rightButton, .wheelPress, .dpiButton, .thumbFront, .thumbRear: nil
        }
    }

    var clearestSide: MouseSide {
        switch self {
        case .leftButton, .rightButton, .wheelPress, .dpiButton: .fingerSide
        case .thumbFront, .thumbRear, .joystickUp, .joystickDown, .joystickLeft, .joystickRight, .joystickPress:
            .thumbSide
        }
    }

    var directionSymbol: String? {
        switch self {
        case .joystickUp: "arrow.up"
        case .joystickDown: "arrow.down"
        case .joystickLeft: "arrow.left"
        case .joystickRight: "arrow.right"
        case .joystickPress: "smallcircle.filled.circle"
        case .leftButton, .rightButton, .wheelPress, .dpiButton, .thumbFront, .thumbRear: nil
        }
    }

    /// The title with its group, for VoiceOver, which reads a row without its section header.
    var spokenTitle: String {
        switch self {
        case .joystickUp, .joystickDown, .joystickLeft, .joystickRight, .joystickPress: "Joystick \(title)"
        case .thumbFront, .thumbRear: "Thumb \(title)"
        case .leftButton, .rightButton, .wheelPress, .dpiButton: title
        }
    }
}

private struct LeaderLine: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

/// A button's assignment as a row in its group; clicking it opens the editor.
private struct DiagramRow: View {
    let title: String
    let spokenTitle: String
    let symbol: String?
    @Binding var action: ButtonAction
    /// Puts the assignment under the title, for a column too narrow to hold them side by side.
    let stacksValue: Bool
    /// Called when the row starts or stops being pointed at or edited.
    let onActiveChange: (Bool) -> Void
    @State private var isEditing = false
    @State private var isHovered = false

    private var isActive: Bool {
        isHovered || isEditing
    }

    var body: some View {
        Button {
            isEditing = true
        } label: {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                }
                if stacksValue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                        ActionSummary(action: action)
                    }
                    Spacer(minLength: 4)
                } else {
                    Text(title)
                    Spacer(minLength: 8)
                    ActionSummary(action: action)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
            .lineLimit(1)
            .padding(.horizontal, DiagramLayout.rowInset)
            .frame(maxWidth: .infinity, minHeight: stacksValue ? 56 : 40)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(isActive ? 0.07 : 0))
                    .padding(4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onChange(of: isActive) { _, isActive in
            onActiveChange(isActive)
        }
        .animation(.easeOut(duration: 0.12), value: isActive)
        .accessibilityLabel("Change what \(spokenTitle) does")
        .popover(isPresented: $isEditing, arrowEdge: .bottom) {
            ActionEditor(action: $action)
        }
    }
}
