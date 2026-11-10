import SwiftUI
import ZelotesKit

struct DPIPage: View {
    @Binding var dpi: DPISettings
    @Binding var stageNames: DPIStageNames
    let hasDPIStageButton: Bool
    let chooseStage: (Int) -> Void
    let showButtons: () -> Void

    var body: some View {
        Form {
            Section {
                ForEach(DPISettings.stages, id: \.self) { stage in
                    DPIStageRow(
                        stage: stage,
                        dpi: stageBinding(stage),
                        names: $stageNames,
                        isActive: dpi.activeStage == stage,
                        chooseStage: chooseStage
                    )
                }
                if !hasDPIStageButton {
                    noStageButtonWarning
                }
            } header: {
                TitleWithInfo(title: "DPI Stages", info: Self.stagesInfo)
            }
            Section {
                LabeledContent {
                    Picker("Polling Rate", selection: $dpi.pollingRate) {
                        ForEach(PollingRate.allCases, id: \.self) { rate in
                            Text(verbatim: "\(rate.rawValue) Hz").tag(rate)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    TitleWithInfo(title: "Polling Rate", info: Self.pollingRateInfo)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var noStageButtonWarning: some View {
        HStack {
            Label("No button switches stages.", systemImage: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Assign a Button", action: showButtons)
                .buttonStyle(.link)
        }
    }

    private static let stagesInfo = "DPI is how sensitive the mouse is: the higher the number, the farther the "
        + "pointer moves for the same movement of your hand. Click a stage to make it active; if this preset is in "
        + "a profile, the mouse switches to it right away and makes that profile active. Click its DPI to rename "
        + "it or change the value. A DPI Stage button changes the stage on the mouse without telling the Mac, so "
        + "Active shows the stage chosen here last."

    private static let pollingRateInfo = "How many times a second the mouse sends its movement to the Mac. "
        + "Higher rates make the pointer smoother and quicker to respond; 1000 Hz is the highest."

    private func stageBinding(_ stage: Int) -> Binding<Int> {
        Binding(get: { dpi[stage] }, set: { dpi[stage] = $0 })
    }
}

private struct DPIStageRow: View {
    let stage: Int
    @Binding var dpi: Int
    @Binding var names: DPIStageNames
    let isActive: Bool
    let chooseStage: (Int) -> Void
    @State private var isEditing = false

    private var valueText: String {
        "\(dpi.formatted()) DPI"
    }

    var body: some View {
        LabeledContent {
            PopoverRowButton(open: { isEditing = true }) { isHovered in
                PopoverValueLabel(isHovered: isHovered, isPresented: $isEditing) {
                    Text(verbatim: valueText)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                } editor: {
                    StageEditor(stage: stage, dpi: $dpi, names: $names)
                }
            }
            .accessibilityLabel("Edit Stage \(stage)")
            .layoutPriority(1)
        } label: {
            Button(action: makeActive) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: isActive ? "\(stage).circle.fill" : "\(stage).circle")
                        .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(verbatim: names.title(of: stage))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isActive {
                        ActivePill()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Makes this the active stage")
            .accessibilityAddTraits(isActive ? .isSelected : [])
        }
        .contentShape(.rect)
        .onTapGesture(perform: makeActive)
        .help(isActive ? "" : "Make Active")
        .contextMenu {
            Button("Edit Stage…") { isEditing = true }
            if !names[stage].isEmpty {
                Divider()
                Button("Reset Name") { names[stage] = "" }
            }
        }
    }

    private func makeActive() {
        chooseStage(stage)
    }

    private var accessibilityLabel: String {
        let name = names[stage]
        return (["Stage \(stage)"] + (name.isEmpty ? [] : [name]) + [valueText]).joined(separator: ", ")
    }
}

private struct StageEditor: View {
    let stage: Int
    @Binding var dpi: Int
    @Binding var names: DPIStageNames
    @State private var name: String
    @State private var text = ""
    @FocusState private var isDPIFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private static let lowestDPI = Double(DPISettings.dpiRange.lowerBound)
    private static let dpiSpan = Double(DPISettings.dpiRange.upperBound) / lowestDPI

    init(stage: Int, dpi: Binding<Int>, names: Binding<DPIStageNames>) {
        self.stage = stage
        _dpi = dpi
        _names = names
        _name = State(initialValue: names.wrappedValue[stage])
    }

    private var dpiLabel: String {
        "Stage \(stage) DPI"
    }

    var body: some View {
        Form {
            TextField("Name", text: $name, prompt: Text(verbatim: DPIStageNames.unnamed.title(of: stage)))
                .onSubmit { dismiss() }
            VStack(spacing: 10) {
                LabeledContent("DPI") {
                    HStack(spacing: 8) {
                        TextField(dpiLabel, text: $text)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(width: 64)
                            .focused($isDPIFieldFocused)
                            .onSubmit(applyTypedNumber)
                            .accessibilityLabel(dpiLabel)
                        Stepper(dpiLabel, value: $dpi, in: DPISettings.dpiRange, step: DPISettings.dpiStep)
                            .labelsHidden()
                    }
                }
                Slider(value: logarithmicPosition, in: 0...1) {
                    Text(dpiLabel)
                } minimumValueLabel: {
                    Image(systemName: "tortoise")
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "hare")
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()
                .accessibilityValue("\(dpi.formatted()) DPI")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { isDPIFieldFocused = true }
        .onChange(of: name) { names[stage] = name }
        .onChange(of: text) {
            // Digits on their way to a larger number are below the range; they wait for Return.
            if isDPIFieldFocused, let typed = typedNumber, DPISettings.dpiRange.contains(typed) {
                dpi = typed
            }
        }
        .onChange(of: dpi, initial: true) { _, newValue in
            if !isDPIFieldFocused || typedNumber.map(DPISettings.normalized) != newValue {
                text = newValue.formatted()
            }
        }
        .onChange(of: isDPIFieldFocused) { _, isFocused in
            if !isFocused {
                showStoredValue()
            }
        }
    }

    private var logarithmicPosition: Binding<Double> {
        Binding(
            get: { log(Double(dpi) / Self.lowestDPI) / log(Self.dpiSpan) },
            set: { dpi = Int((Self.lowestDPI * pow(Self.dpiSpan, $0)).rounded()) }
        )
    }

    private var typedNumber: Int? {
        try? Int(text, format: .number)
    }

    private func applyTypedNumber() {
        if let typed = typedNumber {
            dpi = typed
        }
        showStoredValue()
        dismiss()
    }

    private func showStoredValue() {
        text = dpi.formatted()
    }
}

/// A title followed by an ⓘ button that explains it in a popover, for readers who want to know more.
struct TitleWithInfo: View {
    let title: String
    let info: String
    @State private var isShowingInfo = false

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
            Button {
                isShowingInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("About \(title)")
            .accessibilityLabel("About \(title)")
            .popover(isPresented: $isShowingInfo, arrowEdge: .bottom) {
                Text(info)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
            }
        }
    }
}
