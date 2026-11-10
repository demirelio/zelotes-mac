import SwiftUI

/// A photo of the mouse from one side and the outline of each button on it.
struct MouseArt {
    struct Region: Identifiable {
        let id: String
        let outline: Path
    }

    /// A small triangle with its point at `tip`, facing away from `tail`: the way an input is moved.
    struct Pointer {
        let tail: CGPoint
        let tip: CGPoint
    }

    static let fingerSide = MouseArt(named: "c18-finger")
    static let thumbSide = MouseArt(named: "c18-thumb")

    let photo: Image
    /// The photo's size in pixels, which is also the coordinate space of everything below.
    let size: CGSize
    let regions: [Region]
    /// Where leader lines end, by element id.
    let spots: [String: CGPoint]
    let pointers: [String: Pointer]

    /// Reads `name.png` and its button map `name.svg` from the app's resources.
    private init(named name: String) {
        let reader = ButtonMapReader()
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"), let parser = XMLParser(contentsOf: url) {
            parser.delegate = reader
            parser.parse()
        }
        let image = Bundle.main.url(forResource: name, withExtension: "png").flatMap(NSImage.init(contentsOf:))
        photo = Image(nsImage: image ?? NSImage())
        size = reader.size
        regions = reader.regions
        spots = reader.spots
        pointers = reader.pointers
    }

    /// Where the spot with `id` lands when the photo is fitted in `frame`, or `nil` when this photo has no such spot.
    func position(ofSpot id: String, fittedIn frame: CGRect) -> CGPoint? {
        guard let spot = spots[id] else { return nil }
        let scale = min(frame.width / size.width, frame.height / size.height)
        return CGPoint(
            x: frame.midX + (spot.x - size.width / 2) * scale,
            y: frame.midY + (spot.y - size.height / 2) * scale
        )
    }
}

private final class ButtonMapReader: NSObject, XMLParserDelegate {
    private(set) var size = CGSize(width: 1, height: 1)
    private(set) var regions: [MouseArt.Region] = []
    private(set) var spots: [String: CGPoint] = [:]
    private(set) var pointers: [String: MouseArt.Pointer] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        if elementName == "svg" {
            readSize(fromViewBox: attributes["viewBox"] ?? "")
            return
        }
        guard let id = attributes["id"] else { return }
        switch attributes["class"] {
        case "region":
            regions.append(MouseArt.Region(id: id, outline: Self.path(fromData: attributes["d"] ?? "")))
        case "spot":
            spots[id] = CGPoint(x: Self.number(attributes["cx"]), y: Self.number(attributes["cy"]))
        case "pointer":
            let ends = Self.numbers(in: attributes["d"] ?? "")
            if ends.count == 4 {
                pointers[id] = MouseArt.Pointer(
                    tail: CGPoint(x: ends[0], y: ends[1]),
                    tip: CGPoint(x: ends[2], y: ends[3])
                )
            }
        default:
            break
        }
    }

    private func readSize(fromViewBox viewBox: String) {
        let numbers = viewBox.split(separator: " ").compactMap { Double($0) }
        if numbers.count == 4 {
            size = CGSize(width: numbers[2], height: numbers[3])
        }
    }

    private static func number(_ text: String?) -> CGFloat {
        CGFloat(text.flatMap(Double.init) ?? 0)
    }

    private static func numbers(in data: String) -> [CGFloat] {
        data.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }.map { CGFloat($0) }
    }

    /// Reads path data made of absolute M, L, C and Z commands, which is all the button maps use.
    private static func path(fromData data: String) -> Path {
        var path = Path()
        var command: Character = "M"
        var numbers: [CGFloat] = []
        for token in data.split(whereSeparator: { $0 == " " || $0 == "," }) {
            if token.count == 1, let letter = token.first, letter.isLetter {
                command = letter
                numbers = []
                if letter == "Z" {
                    path.closeSubpath()
                }
                continue
            }
            guard let value = Double(token) else { continue }
            numbers.append(CGFloat(value))
            switch (command, numbers.count) {
            case ("M", 2):
                path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
                command = "L"
                numbers = []
            case ("L", 2):
                path.addLine(to: CGPoint(x: numbers[0], y: numbers[1]))
                numbers = []
            case ("C", 6):
                path.addCurve(
                    to: CGPoint(x: numbers[4], y: numbers[5]),
                    control1: CGPoint(x: numbers[0], y: numbers[1]),
                    control2: CGPoint(x: numbers[2], y: numbers[3])
                )
                numbers = []
            default:
                break
            }
        }
        return path
    }
}

/// Shows the photo with the buttons whose ids are in `lit` glowing in the accent color.
struct MouseArtView: View {
    let art: MouseArt
    let lit: Set<String>
    /// The pointer to draw over the photo, when the photo's map has one with this id.
    let pointerID: String?

    var body: some View {
        ZStack {
            photo
            ZStack {
                ForEach(art.regions) { region in
                    if lit.contains(region.id) {
                        ButtonLight(outline: region.outline, artSize: art.size)
                            .transition(.opacity)
                    }
                }
            }
            .mask { photo }
            .blendMode(.plusLighter)
        }
        .compositingGroup()
        .aspectRatio(art.size.width / art.size.height, contentMode: .fit)
        .overlay {
            if let pointerID, let pointer = art.pointers[pointerID] {
                PointerView(pointer: pointer, artSize: art.size)
                    .id(pointerID)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lit)
        .animation(.easeInOut(duration: 0.25), value: pointerID)
    }

    private var photo: some View {
        art.photo
            .resizable()
            .interpolation(.high)
    }
}

/// One button's light, slowly breathing: a wide bloom, a wash over the button and a bright rim.
private struct ButtonLight: View {
    let outline: Path
    let artSize: CGSize

    var body: some View {
        let shape = ScaledOutline(outline: outline, artSize: artSize)
        ZStack {
            shape.fill(.tint).opacity(0.3).blur(radius: 14)
            shape.fill(.tint).opacity(0.36).blur(radius: 1.5)
            shape.stroke(.tint, lineWidth: 1.5).blur(radius: 0.6)
        }
        .phaseAnimator([false, true]) { light, isDimmed in
            light.opacity(isDimmed ? 0.6 : 1)
        } animation: { _ in
            .easeInOut(duration: 1.2)
        }
    }
}

private struct ScaledOutline: Shape {
    let outline: Path
    let artSize: CGSize

    func path(in rect: CGRect) -> Path {
        outline.applying(CGAffineTransform(scaleX: rect.width / artSize.width, y: rect.height / artSize.height))
    }
}

/// A small triangle over the photo that drifts toward its point. It may reach past the photo's edge.
private struct PointerView: View {
    let pointer: MouseArt.Pointer
    let artSize: CGSize
    private static let drift: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / artSize.width
            let triangle = Triangle(
                tip: CGPoint(x: pointer.tip.x * scale, y: pointer.tip.y * scale),
                direction: direction
            )
            triangle
                .fill(.tint)
                .overlay { triangle.stroke(.tint, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round)) }
                .shadow(color: .black.opacity(0.3), radius: 1.5)
                .phaseAnimator([false, true]) { content, isAhead in
                    content.offset(
                        x: isAhead ? direction.dx * Self.drift : 0,
                        y: isAhead ? direction.dy * Self.drift : 0
                    )
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
        }
        .allowsHitTesting(false)
    }

    private var direction: CGVector {
        let length = max(hypot(pointer.tip.x - pointer.tail.x, pointer.tip.y - pointer.tail.y), 1)
        return CGVector(dx: (pointer.tip.x - pointer.tail.x) / length, dy: (pointer.tip.y - pointer.tail.y) / length)
    }
}

private struct Triangle: Shape {
    let tip: CGPoint
    /// A unit vector from the base toward the point.
    let direction: CGVector
    private static let height: CGFloat = 8
    private static let halfBase: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        let baseCenter = CGPoint(x: tip.x - direction.dx * Self.height, y: tip.y - direction.dy * Self.height)
        let across = CGVector(dx: -direction.dy, dy: direction.dx)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(
            x: baseCenter.x + across.dx * Self.halfBase, y: baseCenter.y + across.dy * Self.halfBase
        ))
        path.addLine(to: CGPoint(
            x: baseCenter.x - across.dx * Self.halfBase, y: baseCenter.y - across.dy * Self.halfBase
        ))
        path.closeSubpath()
        return path
    }
}
