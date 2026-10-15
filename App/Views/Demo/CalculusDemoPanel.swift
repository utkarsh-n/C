import SwiftUI
import CCore

/// The parent owns the demo clock. A manual adjustment pauses that clock and
/// takes ownership of the adjusted value until the parent replays the scene.
struct CalculusDemoPanel: View {
    let step: CDemoStep
    let progress: Double
    let isPlaying: Bool
    let onInteraction: () -> Void

    @State private var manualConstant: Double?
    @State private var manualProbe: Double?
    @State private var manualCount: Int?
    @State private var manualRule: IntegrationRule?
    @State private var reversed = false
    @State private var dragStartConstant: Double?
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isArea: Bool { step == .area }
    private var isAnchor: Bool { step == .anchor }
    private var p: Double { min(1, max(0, progress.isFinite ? progress : 0)) }
    private var constant: Double {
        if let manualConstant { return manualConstant }
        let t = min(1, max(0, (p - 0.12) / 0.72))
        let eased = reduceMotion ? (t < 0.5 ? 0.0 : 1.0) : t * t * (3 - 2 * t)
        return isAnchor ? 3 - eased : 3 * eased
    }
    private var probe: Double { manualProbe ?? (isAnchor ? 0 : 1) }
    private var count: Int {
        manualCount ?? (p < 0.25 || p >= 0.74 ? 8 : p < 0.47 ? 16 : 32)
    }
    private var rule: IntegrationRule { manualRule ?? (p < 0.74 ? .midpoint : .simpson) }
    private var result: IntegrationResult {
        CalculusLab.integrate(.square, from: reversed ? 2 : 0, to: reversed ? 0 : 2,
                              subdivisions: count, rule: rule)
    }
    private var height: Double { CIntegrand.linear.primitive(at: probe, constant: constant) }
    private var slope: Double { CIntegrand.linear.value(at: probe) }

    var body: some View {
        VStack(spacing: 16) {
            InstrumentContentPanel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(isArea ? (reversed ? "∫₂⁰ x² dx = −8 / 3" : "∫₀² x² dx = 8 / 3") : "∫ 2x dx = x² + C")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.displayInk)
                        .accessibilityIdentifier("demo.calculus.equation")
                    Text(isArea ? "\(rule.title) · \(result.subdivisions) intervals · \(reversed ? "2 → 0" : "0 → 2")" : "F(x) = x² + \(format(constant, digits: 2))")
                        .font(.system(.caption, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                    if isArea { areaReadouts } else { curveReadouts }
                    chart
                        .frame(height: dynamicType.isAccessibilitySize ? 240 : 220)
                    legend
                    Text("x is dimensionless · fixed plot scale")
                        .font(.caption)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                }
            }

            Text(meaning)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(InstrumentPalette.displayInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("demo.calculus.meaning")

            if isArea { areaControls } else { curveControls }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing { clearManualValues() }
        }
        .onChange(of: progress) { _, _ in
            if !isPlaying { clearManualValues() }
        }
    }

    private var meaning: String {
        if isArea {
            return rule == .simpson
                ? "Simpson fits this quadratic exactly, apart from floating point roundoff. Reversing the limits reverses the sign."
                : "More rectangles bring the estimate closer to \(reversed ? "−8 / 3" : "8 / 3"). The same +C cancels when two endpoint heights are subtracted."
        }
        if isAnchor {
            return abs(constant - 2) < 0.005
                ? "The point (0, 2) chooses C = 2. Only x² + 2 passes through it."
                : "The slope leaves the height open. Aim the curve through (0, 2) to choose its constant."
        }
        return "C moves every height by the same amount. The tangent slope stays 2x because the derivative of a constant is zero."
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { legendItems }
            VStack(alignment: .leading, spacing: 8) { legendItems }
        }
        .font(.caption)
    }

    @ViewBuilder private var legendItems: some View {
        if isArea {
            Label("x²", systemImage: "waveform.path")
                .foregroundStyle(InstrumentPalette.actionCyan)
            Label(reversed ? "Negative contributions" : "Positive contributions", systemImage: "square.fill")
                .foregroundStyle(reversed ? InstrumentPalette.spectrum : InstrumentPalette.actionAmber)
        } else {
            Label("Selected curve", systemImage: "minus")
                .foregroundStyle(InstrumentPalette.actionCyan)
            Label(isAnchor ? "Target (0, 2)" : "Tangent", systemImage: isAnchor ? "scope" : "line.diagonal")
                .foregroundStyle(InstrumentPalette.actionAmber)
        }
    }

    private var chart: some View {
        GeometryReader { geometry in
            let plot = CGRect(x: 34, y: 16, width: max(1, geometry.size.width - 48), height: max(1, geometry.size.height - 44))
            CalculusDemoPlot(isArea: isArea, isAnchor: isAnchor, constant: constant,
                             probe: probe, result: result, plot: plot)
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        guard !isArea else { return }
                        if dragStartConstant == nil {
                            dragStartConstant = constant
                            onInteraction()
                        }
                        let shifted = (dragStartConstant ?? constant) - Double(value.translation.height / plot.height) * 16
                        manualConstant = min(5, max(-5, shifted))
                    }
                    .onEnded { _ in
                        guard !isArea else { return }
                        dragStartConstant = nil
                        CFeedback.selection()
                    }, including: isArea ? .none : .all)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isArea ? "Numerical integral of x squared" : "Antiderivative curve and tangent")
                .accessibilityValue(isArea
                    ? "\(rule.title), \(result.subdivisions) intervals, estimate \(format(result.estimate)), exact form \(format(result.exact)). \(reversed ? "Limits reversed; contributions are negative." : "Limits zero to two; contributions are positive.")"
                    : "Constant \(format(constant, digits: 2)), x \(format(probe, digits: 1)), height \(format(height)), slope \(format(slope)). \(isAnchor ? "Target point zero, two." : "Other curves have the same slope.")")
                .accessibilityHint(isArea ? "Use the method and interval controls below." : "Drag vertically or adjust the constant slider below.")
                .accessibilityIdentifier("demo.calculus.chart")
        }
        .background(Color(red: 0.022, green: 0.036, blue: 0.047), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.075), lineWidth: 0.6))
    }

    private var curveReadouts: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 12) { curveMetrics }
            } else {
                HStack(alignment: .top, spacing: 8) { curveMetrics }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var curveMetrics: some View {
        InstrumentMetricReadout("CONSTANT C", value: format(constant, digits: 2), unit: "")
            .accessibilityIdentifier("demo.calculus.constant")
        InstrumentMetricReadout("HEIGHT F(x)", value: format(height), unit: "")
            .accessibilityIdentifier("demo.calculus.height")
        InstrumentMetricReadout("SLOPE 2x", value: format(slope), unit: "", color: InstrumentPalette.actionAmber)
            .accessibilityIdentifier("demo.calculus.slope")
    }

    private var areaReadouts: some View {
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 12) { areaMetrics }
            } else {
                HStack(alignment: .top, spacing: 8) { areaMetrics }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var areaMetrics: some View {
        InstrumentMetricReadout("ESTIMATE", value: format(result.estimate), unit: "")
            .accessibilityIdentifier("demo.calculus.estimate")
        InstrumentMetricReadout("EXACT FORM", value: format(result.exact), unit: "", color: InstrumentPalette.actionAmber)
            .accessibilityIdentifier("demo.calculus.exact")
        InstrumentMetricReadout("ABS. ERROR", value: errorFormat(result.absoluteError), unit: "", color: InstrumentPalette.spectrum)
            .accessibilityIdentifier("demo.calculus.error")
    }

    private var curveControls: some View {
        InstrumentContentPanel {
            VStack(spacing: 16) {
                CSlider(title: "Move C", value: Binding(get: { constant }, set: {
                    onInteraction()
                    manualConstant = $0
                }), range: -5...5, step: 0.1, formatted: format(constant, digits: 1))
                    .frame(minHeight: 64)
                    .accessibilityIdentifier("demo.calculus.constant.slider")
                if isAnchor {
                    LabAction(title: "Anchor F(0) = 2", symbol: "scope", accent: InstrumentPalette.actionAmber) {
                        onInteraction()
                        manualConstant = CIntegrand.linear.constant(forValue: 2, at: 0)
                        manualProbe = 0
                        CFeedback.event()
                    }
                    .accessibilityIdentifier("demo.calculus.anchor")
                } else {
                    CSlider(title: "Inspect x", value: Binding(get: { probe }, set: {
                        onInteraction()
                        manualProbe = $0
                    }), range: -2...2, step: 0.1, formatted: format(probe, digits: 1), accent: InstrumentPalette.actionAmber)
                        .frame(minHeight: 64)
                        .accessibilityIdentifier("demo.calculus.probe.slider")
                    HStack(spacing: 12) {
                        constantPreset(0)
                        constantPreset(3)
                    }
                }
                Text("d/dx [x² + C] = 2x + 0")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    private func constantPreset(_ value: Double) -> some View {
        Button {
            onInteraction()
            manualConstant = value
            manualProbe = 1
            CFeedback.selection()
        } label: {
            Text("C = \(Int(value))").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
        .tint(InstrumentPalette.actionCyan)
        .instrumentControlOwnsTouches(identifier: "demoConstant\(Int(value))")
        .accessibilityIdentifier("demo.calculus.preset.\(Int(value))")
    }

    private var areaControls: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Approximation method", selection: Binding(get: { rule }, set: {
                    onInteraction()
                    manualRule = $0
                    CFeedback.selection()
                })) {
                    Text("Midpoint").tag(IntegrationRule.midpoint)
                    Text("Simpson").tag(IntegrationRule.simpson)
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .instrumentControlOwnsTouches(identifier: "demoIntegrationRule")
                .accessibilityIdentifier("demo.calculus.rule")

                Text("Choose how many pieces to add")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                if dynamicType.isAccessibilitySize {
                    VStack(spacing: 10) { intervalButtons }
                } else {
                    HStack(spacing: 10) { intervalButtons }
                }
                LabAction(title: reversed ? "Restore 0 → 2" : "Reverse the limits", symbol: "arrow.left.arrow.right") {
                    onInteraction()
                    reversed.toggle()
                    CFeedback.event()
                }
                .accessibilityIdentifier("demo.calculus.reverse")
                Text("[F(b) + C] − [F(a) + C] = F(b) − F(a)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    @ViewBuilder private var intervalButtons: some View {
        ForEach([8, 16, 32], id: \.self) { n in
            Button {
                onInteraction()
                manualCount = n
                CFeedback.selection()
            } label: {
                Text("n = \(n)")
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .tint(n == result.subdivisions ? InstrumentPalette.actionCyan : InstrumentPalette.secondaryInk)
            .instrumentControlOwnsTouches(identifier: "demoIntervals\(n)")
            .accessibilityAddTraits(n == result.subdivisions ? .isSelected : [])
            .accessibilityIdentifier("demo.calculus.intervals.\(n)")
        }
    }

    private func format(_ value: Double, digits: Int = 4) -> String {
        let rounded = abs(value) < 0.5 * pow(10, -Double(digits)) ? 0 : value
        return String(format: "%.*f", digits, rounded)
    }

    private func errorFormat(_ value: Double) -> String {
        value < 1e-12 ? "< 1e−12" : String(format: "%.2e", value)
    }

    private func clearManualValues() {
        manualConstant = nil
        manualProbe = nil
        manualCount = nil
        manualRule = nil
        reversed = false
        dragStartConstant = nil
    }
}

/// Pure decorative drawing: domain values and all controls are sibling views.
private struct CalculusDemoPlot: View {
    let isArea: Bool
    let isAnchor: Bool
    let constant: Double
    let probe: Double
    let result: IntegrationResult
    let plot: CGRect

    private var xRange: ClosedRange<Double> { isArea ? -0.2...2.2 : -2...2 }
    private var yRange: ClosedRange<Double> { isArea ? -0.5...4.5 : -6...10 }

    var body: some View {
        Canvas { context, _ in
            var context = context
            drawGrid(context: &context)
            var clipped = context
            clipped.clip(to: Path(plot))
            if isArea {
                for slice in result.slices {
                    var piece = Path()
                    piece.move(to: point(slice.start, 0))
                    for i in 0...16 {
                        let t = Double(i) / 16
                        piece.addLine(to: point(slice.start + (slice.end - slice.start) * t,
                                                slice.height(atFraction: t)))
                    }
                    piece.addLine(to: point(slice.end, 0))
                    piece.closeSubpath()
                    let color = slice.signedArea < 0 ? InstrumentPalette.spectrum : InstrumentPalette.actionAmber
                    clipped.fill(piece, with: .color(color.opacity(0.2)))
                    clipped.stroke(piece, with: .color(color.opacity(0.75)), lineWidth: 1)
                }
                clipped.stroke(curve { CIntegrand.square.value(at: $0) },
                               with: .color(InstrumentPalette.actionCyan), lineWidth: 2.5)
                drawBound(result.lower, label: "a", color: InstrumentPalette.actionCyan, context: &clipped)
                drawBound(result.upper, label: "b", color: InstrumentPalette.actionAmber, context: &clipped)
            } else {
                for c in [-3.0, 0, 2, 3] {
                    clipped.stroke(curve { CIntegrand.linear.primitive(at: $0, constant: c) },
                                   with: .color(InstrumentPalette.spectrum.opacity(0.26)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                }
                clipped.stroke(curve { CIntegrand.linear.primitive(at: $0, constant: constant) },
                               with: .color(InstrumentPalette.actionCyan), lineWidth: 3)
                let y = CIntegrand.linear.primitive(at: probe, constant: constant)
                let slope = CIntegrand.linear.value(at: probe)
                var tangent = Path()
                tangent.move(to: point(probe - 0.6, y - slope * 0.6))
                tangent.addLine(to: point(probe + 0.6, y + slope * 0.6))
                clipped.stroke(tangent, with: .color(InstrumentPalette.actionAmber), lineWidth: 2)
                let dot = point(probe, y)
                clipped.fill(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)),
                             with: .color(InstrumentPalette.actionAmber))
                if isAnchor {
                    let target = point(0, 2)
                    let ring = CGRect(x: target.x - 9, y: target.y - 9, width: 18, height: 18)
                    clipped.stroke(Path(ellipseIn: ring), with: .color(InstrumentPalette.actionAmber), lineWidth: 1.5)
                    var guide = Path()
                    guide.move(to: point(-2, 2))
                    guide.addLine(to: point(2, 2))
                    clipped.stroke(guide, with: .color(InstrumentPalette.actionAmber.opacity(0.4)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    clipped.draw(Text("(0, 2)").font(.system(.caption, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.actionAmber),
                                 at: CGPoint(x: target.x + 15, y: target.y - 18), anchor: .leading)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: plot.minX + (x - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound) * plot.width,
                y: plot.maxY - (y - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound) * plot.height)
    }

    private func curve(_ value: (Double) -> Double) -> Path {
        var path = Path()
        for i in 0...180 {
            let x = xRange.lowerBound + (xRange.upperBound - xRange.lowerBound) * Double(i) / 180
            if i == 0 { path.move(to: point(x, value(x))) }
            else { path.addLine(to: point(x, value(x))) }
        }
        return path
    }

    private func drawGrid(context: inout GraphicsContext) {
        let xs: [Double] = isArea ? [0, 1, 2] : [-2, -1, 0, 1, 2]
        let ys: [Double] = isArea ? [0, 2, 4] : [-4, 0, 4, 8]
        for x in xs {
            var line = Path()
            line.move(to: point(x, yRange.lowerBound))
            line.addLine(to: point(x, yRange.upperBound))
            context.stroke(line, with: .color(.white.opacity(x == 0 ? 0.18 : 0.06)), lineWidth: 0.7)
            context.draw(Text("\(Int(x))").font(.system(.caption2, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk),
                         at: CGPoint(x: point(x, 0).x, y: plot.maxY + 13))
        }
        for y in ys {
            var line = Path()
            line.move(to: point(xRange.lowerBound, y))
            line.addLine(to: point(xRange.upperBound, y))
            context.stroke(line, with: .color(.white.opacity(y == 0 ? 0.18 : 0.06)), lineWidth: 0.7)
            context.draw(Text("\(Int(y))").font(.system(.caption2, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk),
                         at: CGPoint(x: plot.minX - 10, y: point(0, y).y), anchor: .trailing)
        }
        context.draw(Text("x").font(.system(.caption2, design: .monospaced))
            .foregroundStyle(InstrumentPalette.secondaryInk),
                     at: CGPoint(x: plot.maxX + 8, y: plot.maxY + 13), anchor: .leading)
    }

    private func drawBound(_ x: Double, label: String, color: Color, context: inout GraphicsContext) {
        var line = Path()
        line.move(to: point(x, 0))
        line.addLine(to: point(x, CIntegrand.square.value(at: x)))
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        context.draw(Text(label).font(.system(.caption, design: .monospaced))
            .foregroundStyle(color), at: CGPoint(x: point(x, 0).x, y: point(x, 0).y + 12))
    }
}
