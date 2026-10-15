import SwiftUI
import CCore

struct CalculusLabView: View {
    @State private var mode: CalculusMode = .constant
    @State private var function: CIntegrand = .linear
    @State private var constant = 0.0
    @State private var probeX = 1.0
    @State private var lower = 0.0
    @State private var upper = 2.0
    @State private var subdivisions = 8
    @State private var rule: IntegrationRule = .midpoint
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var result: IntegrationResult {
        CalculusLab.integrate(function, from: lower, to: upper, subdivisions: subdivisions, rule: rule)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LabHeader(
                    eyebrow: "01 / Calculus",
                    title: "The missing C.",
                    subtitle: "One slope. A whole family of curves. Move the constant, then make a C program add the area."
                )
                Picker("Integral exploration", selection: $mode) {
                    ForEach(CalculusMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("calculus.mode")
                .instrumentControlOwnsTouches(identifier: "calculusMode")

                InstrumentContentPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("INTEGRAND f(x)").font(.system(.caption, design: .monospaced)).tracking(1.5)
                            Spacer()
                            Text("x: −3…3").font(.system(.caption, design: .monospaced))
                        }.foregroundStyle(InstrumentPalette.secondaryInk)
                        Picker("Integrand", selection: $function) {
                            ForEach(CIntegrand.allCases) { function in Text(function.formula).tag(function) }
                        }.pickerStyle(.segmented)
                            .accessibilityIdentifier("calculus.integrand")
                            .instrumentControlOwnsTouches(identifier: "calculusIntegrand")
                        Text(mode == .constant ? "∫ \(function.formula) dx = \(function.primitiveFormula) + C" : "∫ₐᵇ \(function.formula) dx")
                            .font(.system(.title3, design: .monospaced)).foregroundStyle(InstrumentPalette.displayInk)
                            .textSelection(.enabled).accessibilityIdentifier("calculus.equation")
                        CalculusChart(
                            function: function, mode: mode, constant: $constant, probeX: probeX,
                            result: result
                        ).frame(height: 275)
                        chartLegend
                        if mode == .constant {
                            Text("Drag vertically inside the plot to move C. The scale stays fixed.")
                                .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        } else {
                            Text("Amber marks a positive piece; violet marks a negative piece. Color follows each piece’s net contribution.")
                                .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        }
                    }
                }

                if mode == .constant { constantControls } else { areaControls }
                modelNote
                referenceLinks
            }
            .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .background(InstrumentDesignBackground())
        .navigationTitle("Calculus")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("calculus.screen")
        .onChange(of: function) { _, _ in CFeedback.selection() }
        .onChange(of: mode) { _, _ in CFeedback.selection() }
        .onChange(of: rule) { _, _ in CFeedback.selection() }
    }

    private var chartLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { legendItems }
            VStack(alignment: .leading, spacing: 8) { legendItems }
        }.font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
    }

    @ViewBuilder private var legendItems: some View {
        if mode == .constant {
            Label("Selected F(x)", systemImage: "minus").foregroundStyle(InstrumentPalette.actionCyan)
            Label("Same slope, other C", systemImage: "line.3.horizontal").foregroundStyle(InstrumentPalette.spectrum)
        } else {
            Label("f(x)", systemImage: "waveform.path").foregroundStyle(InstrumentPalette.actionCyan)
            Label("Signed \(rule.shapeName)", systemImage: "square.split.diagonal.2x2").foregroundStyle(InstrumentPalette.actionAmber)
        }
    }

    private var constantControls: some View {
        VStack(spacing: 20) {
            InstrumentContentPanel {
                VStack(spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("CONSTANT C").font(.system(.caption, design: .monospaced)).tracking(1.5)
                            .foregroundStyle(InstrumentPalette.secondaryInk)
                        Spacer()
                        Text(format(constant, digits: 1)).font(.system(.largeTitle, design: .rounded, weight: .light))
                            .monospacedDigit().foregroundStyle(InstrumentPalette.actionCyan)
                            .accessibilityIdentifier("calculus.constant.value")
                    }
                    CSlider(title: "Constant of integration", value: $constant,
                            range: CalculusLab.constantRange, step: 0.1, formatted: format(constant, digits: 1))
                        .accessibilityIdentifier("calculus.constant.slider")
                    CSlider(title: "Inspect x", value: $probeX,
                            range: CalculusLab.xRange, step: 0.1, formatted: format(probeX, digits: 1),
                            accent: InstrumentPalette.actionAmber)
                        .accessibilityIdentifier("calculus.probe.slider")
                    if dynamicType.isAccessibilitySize {
                        VStack(spacing: 16) { constantMetrics }
                    } else {
                        HStack(alignment: .top, spacing: 12) { constantMetrics }
                    }
                }
            }
            LabNote(
                title: "Why does +C belong here?",
                text: "Integration recovers a function from its slope. Shifting the whole curve up or down changes its height, but keeps every tangent slope. Each constant selects another antiderivative on this interval.",
                equation: "d/dx [\(function.primitiveFormula) + C] = \(function.formula) + 0"
            )
            LabAction(title: "Anchor F(0) = 2", symbol: "scope", accent: InstrumentPalette.actionAmber) {
                constant = function.constant(forValue: 2, at: 0)
                probeX = 0
                CFeedback.event()
            }.accessibilityIdentifier("calculus.anchor")
            LabNote(
                title: "A point chooses one curve",
                text: "If you also know F(0) = 2, only one curve fits. Tap the anchor to find its C. A starting value supplies the information the slope leaves out.",
                equation: "C = 2 − F₀(0) = \(format(function.constant(forValue: 2, at: 0), digits: 1))"
            )
        }
    }

    @ViewBuilder private var constantMetrics: some View {
        InstrumentMetricReadout("HEIGHT F(x)", value: format(function.primitive(at: probeX, constant: constant)), unit: "")
            .accessibilityIdentifier("calculus.height")
        InstrumentMetricReadout("SLOPE F′(x)", value: format(function.value(at: probeX)), unit: "", color: InstrumentPalette.actionAmber)
            .accessibilityIdentifier("calculus.slope")
        InstrumentMetricReadout("AT x", value: format(probeX, digits: 1), unit: "", color: InstrumentPalette.secondaryInk)
            .accessibilityIdentifier("calculus.probe.value")
    }

    private var areaControls: some View {
        VStack(spacing: 20) {
            InstrumentContentPanel {
                VStack(spacing: 20) {
                    Picker("Numerical integration method", selection: $rule) {
                        ForEach(IntegrationRule.allCases) { rule in Text(rule.title).tag(rule) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("calculus.rule")
                        .instrumentControlOwnsTouches(identifier: "calculusRule")
                    CSlider(title: "Start a", value: $lower, range: CalculusLab.xRange,
                            step: 0.1, formatted: format(lower, digits: 1))
                        .accessibilityIdentifier("calculus.lower")
                    CSlider(title: "End b", value: $upper, range: CalculusLab.xRange,
                            step: 0.1, formatted: format(upper, digits: 1), accent: InstrumentPalette.actionAmber)
                        .accessibilityIdentifier("calculus.upper")
                    InstrumentParameterStepper("SUBDIVISIONS", value: $subdivisions,
                                               in: CalculusLab.subdivisionRange, unit: "n",
                                               onAcceptedChange: { _ in CFeedback.selection() })
                        .accessibilityIdentifier("calculus.subdivisions")
                    if result.subdivisions != subdivisions {
                        Text("Simpson uses the next even count: n = \(result.subdivisions).")
                            .font(.caption).foregroundStyle(InstrumentPalette.actionAmber)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if dynamicType.isAccessibilitySize {
                        VStack(spacing: 16) { areaMetrics }
                    } else {
                        HStack(alignment: .top, spacing: 12) { areaMetrics }
                    }
                    Text("\(result.evaluations) function samples · signed Δx = \(format((upper - lower) / Double(result.subdivisions), digits: 4))")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            LabAction(title: "Reverse the limits", symbol: "arrow.left.arrow.right") {
                swap(&lower, &upper)
                CFeedback.event()
            }.accessibilityIdentifier("calculus.reverse")
            LabNote(title: rule.title + " rule", text: rule.explanation, equation: methodEquation)
            LabNote(
                title: "Area has a sign",
                text: "With a < b, values above the x-axis add; values below subtract. Reverse the limits and every contribution reverses. Equal limits give zero.",
                equation: "∫ₐᵇ f(x) dx = F₀(b) − F₀(a) = \(format(result.exact))"
            )
            LabNote(
                title: "Where did C go?",
                text: "A definite integral compares two heights on the same antiderivative. The same constant appears at both ends, so it cancels.",
                equation: "[F₀(b) + C] − [F₀(a) + C] = F₀(b) − F₀(a)"
            )
            convergencePanel
            VStack(alignment: .leading, spacing: 12) {
                Text("Compute it in C").font(.title3.bold()).foregroundStyle(InstrumentPalette.displayInk)
                Text("This complete C99 program uses the selected function, limits and effective n. Share it, compile on a computer with clang integral.c -lm -o integral, then run ./integral.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                CodeBlock(code: CalculusLab.cSource(function, from: lower, to: upper,
                                                   subdivisions: subdivisions, rule: rule))
                    .accessibilityIdentifier("calculus.c.source")
                Text("The app runs the same numerical rule in Swift. It displays C source; it does not compile C on the phone. Roundoff can cause the last displayed digits to differ.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    @ViewBuilder private var areaMetrics: some View {
        InstrumentMetricReadout("NUMERICAL", value: format(result.estimate), unit: "")
            .accessibilityIdentifier("calculus.estimate")
        InstrumentMetricReadout("EXACT FORM", value: format(result.exact), unit: "", color: InstrumentPalette.actionAmber)
            .accessibilityIdentifier("calculus.exact")
        InstrumentMetricReadout("ABS. ERROR", value: errorFormat(result.absoluteError), unit: "", color: InstrumentPalette.spectrum)
            .accessibilityIdentifier("calculus.error")
    }

    private var methodEquation: String {
        switch rule {
        case .midpoint: "Mₙ = Δx Σ f(a + (i + ½)Δx)"
        case .trapezoid: "Tₙ = Δx [½f(a) + Σf(xᵢ) + ½f(b)]"
        case .simpson: "Sₙ = Δx/3 [f(a) + 4f(x₁) + 2f(x₂) + … + f(b)]"
        }
    }

    private var convergencePanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Watch the error shrink").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                Text("Same function and limits, increasing n. These are measured differences from the known primitive, rather than an error guarantee for arbitrary functions.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                HStack {
                    Text("n").frame(width: 36, alignment: .leading)
                    Text("absolute error")
                }.font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
                let samples = CalculusLab.convergence(function, from: lower, to: upper, rule: rule)
                let maxError = max(samples.map(\.error).max() ?? 0, 1e-14)
                ForEach(samples) { sample in
                    HStack(spacing: 12) {
                        Text("\(sample.subdivisions)").frame(width: 36, alignment: .leading)
                        GeometryReader { geometry in
                            Capsule().fill(InstrumentPalette.spectrum.opacity(0.15))
                            Capsule().fill(InstrumentPalette.spectrum)
                                .frame(width: max(2, geometry.size.width * sample.error / maxError))
                        }.frame(height: 6).accessibilityHidden(true)
                        Text(errorFormat(sample.error)).frame(width: 84, alignment: .trailing)
                    }.font(.system(.caption, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(InstrumentPalette.displayInk)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(sample.subdivisions) intervals, absolute error \(errorFormat(sample.error))")
                }
            }
        }
    }

    private var modelNote: some View {
        LabNote(
            title: "This lab’s boundaries",
            text: "Four smooth functions, dimensionless x from −3 to 3, C from −5 to 5, and 2–128 uniform intervals. Sine uses radians. “Exact form” comes from the analytic primitive, evaluated with floating point. Curves are sampled for drawing; the formulas own the values."
        )
    }

    private var referenceLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Read the mathematics").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
            Link("OpenStax · Antiderivatives", destination: URL(string: "https://openstax.org/books/calculus-volume-1/pages/4-10-antiderivatives")!)
            Link("OpenStax · Fundamental theorem", destination: URL(string: "https://openstax.org/books/calculus-volume-1/pages/5-3-the-fundamental-theorem-of-calculus")!)
            Link("OpenStax · Numerical integration", destination: URL(string: "https://openstax.org/books/calculus-volume-2/pages/3-6-numerical-integration")!)
        }.font(.subheadline).tint(InstrumentPalette.actionCyan).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ value: Double, digits: Int = 4) -> String {
        let rounded = abs(value) < 0.5 * pow(10, -Double(digits)) ? 0 : value
        return String(format: "%.*f", digits, rounded)
    }

    private func errorFormat(_ value: Double) -> String {
        value < 1e-12 ? "< 1e−12" : String(format: "%.2e", value)
    }
}

private enum CalculusMode: String, CaseIterable, Identifiable {
    case constant, area
    var id: String { rawValue }
    var title: String { self == .constant ? "Constant +C" : "Signed area → C" }
}

private struct CalculusChart: View {
    let function: CIntegrand
    let mode: CalculusMode
    @Binding var constant: Double
    let probeX: Double
    let result: IntegrationResult
    @State private var dragStartConstant: Double?

    private var yRange: ClosedRange<Double> {
        let values = (0...120).map { i in
            let x = -3 + Double(i) / 20
            return mode == .constant ? function.primitive(at: x) : function.value(at: x)
        }
        let extra = mode == .constant ? 5.7 : 0.0
        let low = min(0, (values.min() ?? -1) - extra)
        let high = max(0, (values.max() ?? 1) + extra)
        let padding = max(0.3, (high - low) * 0.1)
        return (low - padding)...(high + padding)
    }

    var body: some View {
        GeometryReader { geometry in
            let plot = CGRect(x: 44, y: 18, width: max(1, geometry.size.width - 58), height: geometry.size.height - 50)
            let range = yRange
            Canvas { context, size in
                var context = context
                drawGrid(context: &context, plot: plot, range: range)
                if mode == .constant {
                    for c in [-4.0, -2.0, 0, 2, 4] {
                        let path = curve(plot: plot, range: range) { function.primitive(at: $0, constant: c) }
                        context.stroke(path, with: .color(InstrumentPalette.spectrum.opacity(c == 0 ? 0.5 : 0.24)),
                                       style: StrokeStyle(lineWidth: 1, dash: c == 0 ? [4, 4] : []))
                    }
                    let active = curve(plot: plot, range: range) { function.primitive(at: $0, constant: constant) }
                    context.stroke(active, with: .color(InstrumentPalette.actionCyan), lineWidth: 2.5)
                    drawTangent(context: &context, plot: plot, range: range)
                } else {
                    drawSlices(context: &context, plot: plot, range: range)
                    context.stroke(curve(plot: plot, range: range) { function.value(at: $0) },
                                   with: .color(InstrumentPalette.actionCyan), lineWidth: 2.5)
                    drawEndpoint(result.lower, label: "a", context: &context, plot: plot, range: range,
                                 color: InstrumentPalette.actionCyan)
                    drawEndpoint(result.upper, label: "b", context: &context, plot: plot, range: range,
                                 color: InstrumentPalette.actionAmber)
                }
            }
            .accessibilityHidden(true)
            if mode == .constant {
                Color.clear.frame(width: plot.width, height: plot.height)
                    .contentShape(.rect).position(x: plot.midX, y: plot.midY)
                    .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                        let start = dragStartConstant ?? constant
                        if dragStartConstant == nil { dragStartConstant = start }
                        let delta = -Double(value.translation.height / plot.height) * (range.upperBound - range.lowerBound)
                        let proposed = ((start + delta) * 10).rounded() / 10
                        constant = min(5, max(-5, proposed))
                    }.onEnded { _ in
                        if let start = dragStartConstant, start != constant { CFeedback.selection() }
                        dragStartConstant = nil
                    })
                    .instrumentControlOwnsTouches(identifier: "calculusChartDrag")
                    .accessibilityHidden(true)
            }
        }
        .background(Color(red: 0.022, green: 0.036, blue: 0.047), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12), lineWidth: 0.8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .constant ? "Antiderivative family chart" : "Signed area approximation chart")
        .accessibilityValue(mode == .constant
                            ? "C \(constant.formatted()), at x \(probeX.formatted()), height \(function.primitive(at: probeX, constant: constant).formatted()), slope \(function.value(at: probeX).formatted())"
                            : "\(result.subdivisions) intervals, estimate \(result.estimate.formatted()), signed exact value \(result.exact.formatted())")
        .accessibilityIdentifier("calculus.chart")
    }

    private func point(_ x: Double, _ y: Double, plot: CGRect, range: ClosedRange<Double>) -> CGPoint {
        CGPoint(x: plot.minX + (x + 3) / 6 * plot.width,
                y: plot.maxY - (y - range.lowerBound) / (range.upperBound - range.lowerBound) * plot.height)
    }

    private func curve(plot: CGRect, range: ClosedRange<Double>, function: (Double) -> Double) -> Path {
        Path { path in
            for i in 0...240 {
                let x = -3 + Double(i) / 40
                let p = point(x, function(x), plot: plot, range: range)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
        }
    }

    private func drawGrid(context: inout GraphicsContext, plot: CGRect, range: ClosedRange<Double>) {
        for i in 0...6 {
            let x = Double(i) - 3
            let bottom = point(x, range.lowerBound, plot: plot, range: range)
            let top = point(x, range.upperBound, plot: plot, range: range)
            var line = Path()
            line.move(to: bottom); line.addLine(to: top)
            context.stroke(line, with: .color(.white.opacity(x == 0 ? 0.25 : 0.07)), lineWidth: 0.7)
            context.draw(Text("\(Int(x))").font(.system(size: 10, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk),
                         at: CGPoint(x: bottom.x, y: plot.maxY + 13))
        }
        for i in 0...4 {
            let y = range.lowerBound + (range.upperBound - range.lowerBound) * Double(i) / 4
            var line = Path()
            let left = point(-3, y, plot: plot, range: range)
            line.move(to: left); line.addLine(to: point(3, y, plot: plot, range: range))
            context.stroke(line, with: .color(.white.opacity(0.07)), lineWidth: 0.7)
            context.draw(Text(String(format: "%.1f", y)).font(.system(size: 9, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk),
                         at: CGPoint(x: plot.minX - 6, y: left.y), anchor: .trailing)
        }
        var zero = Path()
        zero.move(to: point(-3, 0, plot: plot, range: range)); zero.addLine(to: point(3, 0, plot: plot, range: range))
        context.stroke(zero, with: .color(.white.opacity(0.35)), lineWidth: 1)
        context.draw(Text("x").font(.system(size: 10, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk),
                     at: CGPoint(x: plot.maxX, y: plot.maxY + 26))
        context.draw(Text(mode == .constant ? "F(x)" : "f(x)").font(.system(size: 10, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk),
                     at: CGPoint(x: plot.minX, y: 7), anchor: .leading)
    }

    private func drawTangent(context: inout GraphicsContext, plot: CGRect, range: ClosedRange<Double>) {
        let y = function.primitive(at: probeX, constant: constant)
        let slope = function.value(at: probeX)
        let halfWidth = min(0.35, 2 / max(1, abs(slope)))
        let start = max(-3, probeX - halfWidth)
        let end = min(3, probeX + halfWidth)
        var tangent = Path()
        tangent.move(to: point(start, y + (start - probeX) * slope, plot: plot, range: range))
        tangent.addLine(to: point(end, y + (end - probeX) * slope, plot: plot, range: range))
        context.stroke(tangent, with: .color(InstrumentPalette.actionAmber), lineWidth: 3)
        let center = point(probeX, y, plot: plot, range: range)
        context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                     with: .color(InstrumentPalette.actionAmber))
    }

    private func drawSlices(context: inout GraphicsContext, plot: CGRect, range: ClosedRange<Double>) {
        for slice in result.slices {
            let color = slice.signedArea >= 0 ? InstrumentPalette.actionAmber : InstrumentPalette.spectrum
            var shape = Path()
            shape.move(to: point(slice.start, 0, plot: plot, range: range))
            let segments = slice.rule == .simpson ? 16 : 1
            for i in 0...segments {
                let t = Double(i) / Double(segments)
                let x = slice.start + (slice.end - slice.start) * t
                shape.addLine(to: point(x, slice.height(atFraction: t), plot: plot, range: range))
            }
            shape.addLine(to: point(slice.end, 0, plot: plot, range: range)); shape.closeSubpath()
            context.fill(shape, with: .color(color.opacity(0.16)))
            context.stroke(shape, with: .color(color.opacity(0.48)), lineWidth: 0.8)
            if slice.rule == .midpoint {
                let p = point((slice.start + slice.end) / 2, slice.middleHeight, plot: plot, range: range)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(color))
            }
        }
    }

    private func drawEndpoint(_ x: Double, label: String, context: inout GraphicsContext,
                              plot: CGRect, range: ClosedRange<Double>, color: Color) {
        var line = Path()
        let base = point(x, 0, plot: plot, range: range)
        line.move(to: point(x, range.lowerBound, plot: plot, range: range))
        line.addLine(to: point(x, range.upperBound, plot: plot, range: range))
        context.stroke(line, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        context.draw(Text(label).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(color),
                     at: CGPoint(x: base.x, y: plot.minY + 10))
    }
}
