import Foundation

/// The `HIDPointerAccelerationTable` that macOS's pointer filter reads: pointer movement against mouse movement,
/// joined by straight lines. Layout, all big-endian and 16.16 fixed point unless noted: scale, the signature
/// `@200` (four bytes), the curve count (16 bits), then per curve its acceleration index, its point count
/// (16 bits) and the points as x, y pairs.
enum PointerAccelerationTable {
    /// The report rate the filter is told about. It then divides each report's movement by the milliseconds since
    /// the previous report, never by less than one, so at any polling rate up to 1000 Hz the table sees counts per
    /// millisecond.
    static let reportRate = 1000

    private static let signature: [UInt8] = Array("@200".utf8)
    /// The filter scales a table's mouse values by resolution / 67 and its pointer values by 96 / 67
    /// (`IOHIDTableAcceleration` in Apple's IOHIDFamily).
    private static let filterFrameRate = 67.0
    private static let filterCursorScale = 96.0 / 67.0
    /// Hand speeds sampled for the table, in inches per second; the table runs straight on past the last one.
    private static let handSpeeds = (0..<48).map { 0.05 * pow(200 / 0.05, Double($0) / 47) }
    private static let largestFixed = Double(Int32.max) / 65536

    /// A table that moves the pointer `speed` points per count at slow hand speeds, accelerated by `curve`.
    /// `dpi` turns counts into hand speed; `resolution` is the counts per inch the filter assumes.
    static func data(for curve: AccelerationCurve, speed: Double, dpi: Int, resolution: Double) -> Data {
        var points: [(x: Int32, y: Int32)] = []
        for handSpeed in (handSpeeds + curve.corners).sorted() where handSpeed > 0 {
            let countsPerMillisecond = handSpeed * Double(dpi) / 1000
            let pointerCounts = countsPerMillisecond * speed * curve.gain(atHandSpeed: handSpeed)
            guard let x = fixed(countsPerMillisecond * filterFrameRate / resolution),
                  let y = fixed(pointerCounts / filterCursorScale),
                  x > points.last?.x ?? 0 else { continue }
            points.append((x, y))
        }
        // The same curve at the lowest and the highest index, so the index System Settings sets has no effect.
        let indexes = [0.0, largestFixed]
        var bytes = bigEndian(Int32(65536)) + signature + bigEndian(UInt16(indexes.count))
        for index in indexes {
            bytes += bigEndian(fixed(index) ?? 0) + bigEndian(UInt16(points.count))
            for point in points {
                bytes += bigEndian(point.x) + bigEndian(point.y)
            }
        }
        return Data(bytes)
    }

    /// The first well-formed table in `bytes`. The filter keeps its own default table compiled in, and this finds
    /// it in the installed filter, because a table set on a service cannot be removed again, only replaced.
    static func firstTable(in bytes: Data) -> Data? {
        var searchStart = bytes.startIndex
        while let match = bytes[searchStart...].firstRange(of: signature) {
            searchStart = match.upperBound
            let start = match.lowerBound - 4
            guard start >= bytes.startIndex, let end = endOfTable(in: bytes, from: start) else { continue }
            return Data(bytes[start..<end])
        }
        return nil
    }

    static let installedFilter = URL(
        fileURLWithPath: "/System/Library/HIDPlugins/IOHIDPointerScrollFilter.plugin/Contents/MacOS/IOHIDPointerScrollFilter"
    )

    /// The filter's own default table, or `nil` when it cannot be found in the installed filter.
    static func systemDefault() -> Data? {
        (try? Data(contentsOf: installedFilter, options: .mappedIfSafe)).flatMap(firstTable)
    }

    private static func endOfTable(in bytes: Data, from start: Data.Index) -> Data.Index? {
        var offset = start + 8
        guard let curveCount = uInt16(in: bytes, at: offset), (1...16).contains(curveCount) else { return nil }
        offset += 2
        var previousIndex = Int32.min
        for _ in 0..<curveCount {
            guard let index = int32(in: bytes, at: offset), index > previousIndex,
                  let pointCount = uInt16(in: bytes, at: offset + 4), (1...64).contains(pointCount) else { return nil }
            previousIndex = index
            offset += 6
            var previousX = Int32.min
            for _ in 0..<pointCount {
                guard let x = int32(in: bytes, at: offset), x > previousX, int32(in: bytes, at: offset + 4) != nil else {
                    return nil
                }
                previousX = x
                offset += 8
            }
        }
        return offset
    }

    private static func fixed(_ value: Double) -> Int32? {
        let raw = (value * 65536).rounded()
        guard raw > 0, raw <= Double(Int32.max) else { return nil }
        return Int32(raw)
    }

    private static func bigEndian<Value: FixedWidthInteger>(_ value: Value) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }

    private static func uInt16(in bytes: Data, at offset: Data.Index) -> Int? {
        guard offset >= bytes.startIndex, offset + 2 <= bytes.endIndex else { return nil }
        return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
    }

    private static func int32(in bytes: Data, at offset: Data.Index) -> Int32? {
        guard offset >= bytes.startIndex, offset + 4 <= bytes.endIndex else { return nil }
        let raw = bytes[offset..<offset + 4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return Int32(bitPattern: raw)
    }
}
