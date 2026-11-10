import SwiftUI
import ZelotesKit

/// The mouse's lighting for this preset. Part of the draft: Save sends it with the DPI settings.
struct LightingPage: View {
    @Binding var lighting: Lighting

    var body: some View {
        Form {
            Section {
                Picker("Effect", selection: $lighting.effect) {
                    ForEach(LightingEffect.allCases, id: \.self) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                TitleWithInfo(title: "Effect", info: Self.effectInfo)
            }
            switch lighting.effect {
            case .steady:
                Section {
                    LabeledContent("Color") {
                        ColorSwatches(selection: $lighting.color)
                    }
                    Picker("Brightness", selection: $lighting.brightness) {
                        ForEach(LightBrightness.allCases, id: \.self) { brightness in
                            Text(brightness.title).tag(brightness)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            case .breathing, .neon, .wave, .flowing:
                Section {
                    Picker("Speed", selection: $lighting.speed) {
                        ForEach(LightSpeed.allCases, id: \.self) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            case .off:
                EmptyView()
            }
        }
        .formStyle(.grouped)
    }

    private static let effectInfo = "Steady keeps the mouse lit in one color. Breathing, Neon, Wave and Flowing are "
        + "animated and move through red, green, blue, yellow, magenta, cyan and white. The lighting belongs to the "
        + "preset and goes to the mouse with Save, together with the DPI settings."
}

/// A row of color circles like the accent colors in System Settings, the chosen one marked with a dot.
private struct ColorSwatches: View {
    @Binding var selection: LightColor

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LightColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.swatch)
                        .overlay {
                            Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .overlay {
                            if selection == color {
                                Circle()
                                    .fill(color == .white ? Color.secondary : Color.white)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(width: 18, height: 18)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help(color.title)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }
}

private extension LightColor {
    var swatch: Color {
        switch self {
        case .red: .red
        case .green: .green
        case .blue: .blue
        case .yellow: .yellow
        case .magenta: Color(red: 0.88, green: 0.25, blue: 0.86)
        case .cyan: .cyan
        case .white: .white
        }
    }
}
