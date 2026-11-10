import Charts
import SwiftUI
import ZelotesKit

/// How macOS moves the pointer while this preset's profile is active. Every change applies at once.
struct PointerPage: View {
    @Binding var pointer: PointerSettings
    let status: MappingModel.PointerStatus
    let agentState: PointerAgent.State
    let canMakeProfileActive: Bool
    let makeActive: (MouseProfile) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("Acceleration", selection: $pointer.acceleration) {
                        ForEach(PointerAcceleration.allCases, id: \.self) { acceleration in
                            Text(acceleration.title).tag(acceleration)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } label: {
                    TitleWithInfo(title: "Acceleration", info: Self.accelerationInfo)
                }
                if pointer.curve == nil {
                    systemSettingsRow
                } else if !agentState.allowsPointerSettings {
                    helperNotice
                } else if let curve = pointer.curve {
                    AccelerationChart(curve: curve, speed: pointer.speed)
                    if status != .inUse {
                        statusRow
                    }
                }
            }
            if pointer.curve != nil, agentState.allowsPointerSettings {
                Section {
                    LabeledContent {
                        SliderWithValue(value: speedText) {
                            Slider(value: logarithmic($pointer.speed, in: PointerSettings.speedRange), in: 0...1) {
                                Text("Pointer Speed")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise")
                                    .foregroundStyle(.secondary)
                            } maximumValueLabel: {
                                Image(systemName: "hare")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        TitleWithInfo(title: "Pointer Speed", info: Self.speedInfo)
                    }
                }
            }
            if pointer.acceleration == .custom, agentState.allowsPointerSettings {
                customCurveSection
            }
        }
        .formStyle(.grouped)
    }

    private var customCurveSection: some View {
        Section {
            LabeledContent("Starts At") {
                SliderWithValue(value: HandSpeed.text(pointer.custom.threshold)) {
                    Slider(value: $pointer.custom.threshold, in: CustomCurve.thresholdRange) {
                        Text("Starts At")
                    }
                }
            }
            LabeledContent("Acceleration") {
                SliderWithValue(value: nil) {
                    Slider(value: logarithmic($pointer.custom.strength, in: CustomCurve.strengthRange), in: 0...1) {
                        Text("Acceleration")
                    } minimumValueLabel: {
                        Text("Gentle")
                    } maximumValueLabel: {
                        Text("Strong")
                    }
                }
            }
            LabeledContent("Limit") {
                SliderWithValue(value: Self.multiple(pointer.custom.limit)) {
                    Slider(value: $pointer.custom.limit, in: CustomCurve.limitRange) {
                        Text("Limit")
                    }
                }
            }
        } header: {
            TitleWithInfo(title: "Custom Curve", info: Self.customInfo)
        }
    }

    @ViewBuilder private var statusRow: some View {
        Group {
            switch status {
            case .inUse:
                EmptyView()
            case .inReserve:
                Label("This preset is in Reserve. Its pointer settings apply once it is in the active profile.",
                      systemImage: "tray")
            case .profileNotActive(let profile):
                HStack {
                    Label("Applies while Profile \(profile.rawValue) is active.", systemImage: "info.circle")
                    Spacer()
                    if canMakeProfileActive {
                        Button("Make Active") { makeActive(profile) }
                            .buttonStyle(.link)
                    }
                }
            case .mouseNotConnected:
                Label("Applies when the mouse is connected.", systemImage: "computermouse")
            case .refused(let reason):
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .foregroundStyle(.secondary)
    }

    /// Shown instead of the settings while the agent that sets them again after unplugging cannot run.
    private var helperNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(agentState == .missing ? "Pointer Helper Missing" : "Allow ZelotesMac in the Background")
                    .font(.headline)
                Text(agentState == .missing ? Self.helperMissingMessage : Self.helperTurnedOffMessage)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if agentState == .turnedOffByUser {
                    Button("Open Login Items…") { PointerAgent.openLoginItemsSettings() }
                        .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private static let helperTurnedOffMessage = "A small helper sets the pointer each time the mouse is plugged "
        + "in, then quits. It is turned off in System Settings › General › Login Items › Allow in the Background, "
        + "so the mouse uses macOS’s acceleration until you turn ZelotesMac on there."

    private static let helperMissingMessage = "The helper that sets the pointer each time the mouse is plugged in "
        + "is not in this copy of the app, so the mouse uses macOS’s acceleration."

    private var systemSettingsRow: some View {
        HStack {
            Text("macOS uses Tracking Speed and Pointer Acceleration from System Settings.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Mouse Settings") { openURL(Self.mouseSettings) }
                .buttonStyle(.link)
        }
    }

    private var speedText: String {
        Self.multiple(pointer.speed, fractionDigits: 2)
    }

    private static func multiple(_ value: Double, fractionDigits: Int = 1) -> String {
        "\(value.formatted(.number.precision(.fractionLength(fractionDigits))))×"
    }

    private func logarithmic(_ value: Binding<Double>, in range: ClosedRange<Double>) -> Binding<Double> {
        let span = log(range.upperBound / range.lowerBound)
        return Binding(
            get: { log(value.wrappedValue / range.lowerBound) / span },
            set: { value.wrappedValue = range.lowerBound * exp($0 * span) }
        )
    }

    private static let mouseSettings = URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension")!

    private static let accelerationInfo = "Acceleration makes the pointer travel farther when you move the mouse "
        + "quickly, so slow movements stay precise and quick ones cross the screen. macOS uses its own curve and the "
        + "settings in System Settings › Mouse. Windows uses the curve of Windows’ Enhance Pointer Precision. None "
        + "moves the pointer the same distance at every speed. Custom lets you shape the curve.\n\n"
        + "The setting is for this mouse only: other mice and the trackpad keep macOS’s acceleration. It applies "
        + "while this preset’s profile is active, and macOS drops it when the mouse is unplugged. Each time the mouse "
        + "is plugged in, a small helper sets it again and quits, so the app itself does not need to be open."

    private static let speedInfo = "How far the pointer moves when you move the mouse slowly. The DPI stage changes "
        + "it too: at twice the DPI, the pointer moves twice as far."

    private static let customInfo = "The pointer does not accelerate while your hand moves slower than Starts At. "
        + "Faster than that, Acceleration sets how quickly the pointer speeds up, and Limit is the most it speeds up."
}

/// A slider with its value as text after it, in a column of the same width on every row.
private struct SliderWithValue<Content: View>: View {
    let value: String?
    @ViewBuilder let slider: Content

    var body: some View {
        HStack(spacing: 10) {
            slider
                .labelsHidden()
                .frame(minWidth: 160, idealWidth: 280, maxWidth: 300)
                .accessibilityValue(value ?? "")
            Text(verbatim: value ?? "")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

/// Hand speed in the units of the user's measurement system.
private enum HandSpeed {
    static var usesInches: Bool {
        Locale.current.measurementSystem == .us
    }

    static var unit: String {
        usesInches ? "in/s" : "cm/s"
    }

    static func displayValue(_ inchesPerSecond: Double) -> Double {
        usesInches ? inchesPerSecond : inchesPerSecond * 2.54
    }

    static func text(_ inchesPerSecond: Double) -> String {
        "\(displayValue(inchesPerSecond).formatted(.number.precision(.fractionLength(1)))) \(unit)"
    }
}

/// Pointer speed against hand speed, with the speed it would have without acceleration as a dashed line.
private struct AccelerationChart: View {
    let curve: AccelerationCurve
    let speed: Double

    /// Inches per second, a quick sweep across a desk.
    private static let fastestHandSpeed = 20.0

    private var handSpeeds: [Double] {
        let steps = (0...200).map { Self.fastestHandSpeed * Double($0) / 200 }
        let corners = curve.corners.filter { $0 < Self.fastestHandSpeed }
        return Set(steps + corners).sorted()
    }

    private var highestPointerSpeed: Double {
        handSpeeds.map { speed * curve.gain(atHandSpeed: $0) }.max() ?? speed
    }

    var body: some View {
        Chart {
            ForEach(handSpeeds, id: \.self) { handSpeed in
                LineMark(
                    x: .value("Hand Speed", HandSpeed.displayValue(handSpeed)),
                    y: .value("Pointer Speed", speed * curve.gain(atHandSpeed: handSpeed))
                )
                .interpolationMethod(.linear)
            }
            if curve != .none {
                RuleMark(y: .value("Without Acceleration", speed))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Without acceleration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXScale(domain: 0...HandSpeed.displayValue(Self.fastestHandSpeed))
        .chartYScale(domain: 0...max(highestPointerSpeed * 1.15, speed * 1.5))
        .chartXAxisLabel("Hand speed (\(HandSpeed.unit))", alignment: .center)
        .chartYAxisLabel("Pointer speed")
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let multiple = value.as(Double.self) {
                        Text(verbatim: "\(multiple.formatted(.number.precision(.fractionLength(0...1))))×")
                    }
                }
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }
}
