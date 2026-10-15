import SwiftUI
import UIKit

struct LabHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(InstrumentPalette.actionCyan)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(InstrumentPalette.displayInk)
            Text(subtitle).font(.subheadline)
                .foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LabNote: View {
    let title: String
    let text: String
    var equation: String? = nil
    var body: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                if let equation {
                    Text(equation).font(.system(.callout, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.actionCyan).textSelection(.enabled)
                }
                Text(text).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LabAction: View {
    let title: String
    let symbol: String
    var accent: Color = InstrumentPalette.actionCyan
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(accent).frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.glass)
        .instrumentControlOwnsTouches(identifier: title)
    }
}

struct CodeBlock: View {
    let code: String
    var language: String = "C"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.uppercased()).tracking(1.5)
                Spacer()
                ShareLink(item: code) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Share \(language) code")
            }.font(.system(.caption, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk)
            ScrollView(.horizontal) {
                Text(code).font(.system(.callout, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.actionCyan)
                    .textSelection(.enabled).fixedSize(horizontal: true, vertical: true)
                    .padding(.bottom, 6)
            }
        }.padding(16)
            .background(Color(red: 0.022, green: 0.036, blue: 0.047), in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.09)))
    }
}

struct CSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatted: String
    var accent: Color = InstrumentPalette.actionCyan
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                Spacer()
                Text(formatted).font(.system(.body, design: .rounded, weight: .medium))
                    .monospacedDigit().foregroundStyle(accent)
            }
            Slider(value: $value, in: range, step: step, onEditingChanged: { editing in
                if !editing { CFeedback.selection() }
            }).tint(accent).accessibilityLabel(title).accessibilityValue(formatted)
                .instrumentControlOwnsTouches(identifier: title)
        }
    }
}

@MainActor enum CFeedback {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func event() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
}

struct CSectionLabel: View {
    let number: String
    let title: String
    var color: Color = InstrumentPalette.actionCyan
    var body: some View {
        HStack(spacing: 10) {
            Text(number).foregroundStyle(color)
            Text(title.uppercased()).foregroundStyle(InstrumentPalette.secondaryInk)
        }.font(.system(.caption, design: .monospaced)).tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
