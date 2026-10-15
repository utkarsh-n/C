import SwiftUI
import CCore

/// The demo transport supplies time; LanguageSession supplies every code event.
struct CodeDemoPanel: View {
    let step: CDemoStep
    let progress: Double
    let isPlaying: Bool
    let onInteraction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var language: ProgrammingLanguage = .c
    @State private var seed = 7
    @State private var session: LanguageSession
    @State private var manualSnapshot = false
    @State private var resumeProgress = 0.0
    @State private var resumeEvent = 0
    private static let divisionStart = LanguageSession(program: .division)
    private static let aliasingStart = LanguageSession(program: .aliasing)
    private static let loopStart = LanguageSession(program: .arraySum)

    init(step: CDemoStep, progress: Double, isPlaying: Bool,
         onInteraction: @escaping () -> Void) {
        self.step = step
        self.progress = progress
        self.isPlaying = isPlaying
        self.onInteraction = onInteraction
        var initial: LanguageSession
        switch Self.program(for: step) {
        case .division: initial = Self.divisionStart
        case .aliasing: initial = Self.aliasingStart
        case .arraySum: initial = Self.loopStart
        }
        let events = Int((Self.bounded(progress / 0.88) * Double(initial.totalSteps)).rounded(.down))
        for _ in 0..<events { initial.advance() }
        _session = State(initialValue: initial)
    }

    private static func program(for step: CDemoStep) -> LanguageProgram {
        switch step {
        case .aliases: .aliasing
        case .loops: .arraySum
        default: .division
        }
    }

    private static func bounded(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    private var accent: Color {
        language == .c ? InstrumentPalette.actionCyan : InstrumentPalette.spectrum
    }

    var body: some View {
        VStack(spacing: 16) {
            InstrumentContentPanel {
                VStack(alignment: .leading, spacing: 16) {
                    status
                    currentStatement
                    memoryDiagram
                    Text(session.frame.explanation)
                        .font(.subheadline)
                        .foregroundStyle(InstrumentPalette.displayInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("demo.code.explanation")
                    console
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            controls
            sourceTrace
            Text(language == .c
                 ? "Guided C trace. Addresses are illustrative; completed values remain as a snapshot after return."
                 : "Guided C# trace. Object labels identify shared objects; they are not memory addresses.")
                .font(.caption)
                .foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: progress) { old, new in
            guard old != new else { return }
            if !isPlaying {
                manualSnapshot = false
                resumeProgress = 0
                resumeEvent = 0
            }
            synchronizeProgress()
        }
        .onChange(of: isPlaying) { _, playing in
            if playing, manualSnapshot {
                resumeProgress = Self.bounded(progress)
                resumeEvent = session.completedSteps
                manualSnapshot = false
            }
        }
        .onChange(of: step) { _, _ in resetTrace() }
    }

    private var currentStatement: some View {
        let number = session.frame.line ?? session.nextLine
        let code = number.map { session.codeLines[$0 - 1].trimmingCharacters(in: .whitespaces) } ?? "Trace complete"
        return VStack(alignment: .leading, spacing: 6) {
            Text(session.frame.line == nil ? "NEXT STATEMENT" : "LAST EXECUTED")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk)
            ScrollView(.horizontal) {
                Text(code).font(.system(.callout, design: .monospaced, weight: .semibold))
                    .foregroundStyle(InstrumentPalette.actionAmber)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(InstrumentPalette.actionAmber.opacity(0.07), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demo.code.statement")
    }

    private var status: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(language == .c ? "C memory bench" : "C# object bench", systemImage: "cpu")
                .font(.headline)
                .foregroundStyle(accent)
            Spacer(minLength: 4)
            Text("\(session.completedSteps)/\(session.totalSteps)")
                .font(.system(.subheadline, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(InstrumentPalette.actionAmber)
                .accessibilityLabel("\(session.completedSteps) of \(session.totalSteps) events completed")
                .accessibilityIdentifier("demo.code.events")
        }
    }

    @ViewBuilder private var memoryDiagram: some View {
        switch session.program {
        case .division: divisionDiagram
        case .aliasing: aliasDiagram
        case .arraySum: loopDiagram
        }
    }

    private var divisionDiagram: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("n")
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                Image(systemName: "equal")
                Text(value("n"))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("int").font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(accent)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("demo.code.n")
            resultPath(name: "q", expression: "n / 2", type: "int", detail: "Integer division drops the fraction.", color: accent)
            resultPath(name: "trap", expression: "n / 2", type: "double", detail: "Convert the already divided integer.", color: InstrumentPalette.actionAmber)
            resultPath(name: "real", expression: "n / 2.0", type: "double", detail: "A floating operand keeps the fraction.", color: InstrumentPalette.spectrum)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: session.completedSteps)
    }

    private func resultPath(name: String, expression: String, type: String,
                            detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    expressionLabel(expression, color: color)
                    Image(systemName: "arrow.right").foregroundStyle(color)
                    Spacer(minLength: 0)
                    resultLabel(name: name, type: type, color: color)
                }
                VStack(alignment: .leading, spacing: 8) {
                    expressionLabel(expression, color: color)
                    resultLabel(name: name, type: type, color: color)
                }
            }
            Text(detail).font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(InstrumentPalette.canvas, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.22)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demo.code.value.\(name)")
    }

    private func expressionLabel(_ expression: String, color: Color) -> some View {
        Text(expression).font(.system(.callout, design: .monospaced, weight: .semibold))
            .foregroundStyle(color).fixedSize()
    }

    private func resultLabel(name: String, type: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(name) · \(type)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk)
            Text(value(name)).font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit().foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var aliasDiagram: some View {
        VStack(alignment: .leading, spacing: 12) {
            if language == .c {
                variableCard(name: "p", title: "p · int *", color: InstrumentPalette.actionAmber,
                             detail: session.frame.value(named: "p") == nil ? "Pointer appears at &value." : "Points to value")
                relationLabel(session.frame.value(named: "p") == nil ? "waiting for address" : "dereference *p", color: InstrumentPalette.actionAmber)
                variableCard(name: "value", title: "value · int", color: accent, detail: "One modeled integer object")
            } else {
                if dynamicType.isAccessibilitySize {
                    referenceCard("first")
                    referenceCard("alias")
                } else {
                    HStack(spacing: 12) {
                        referenceCard("first")
                        referenceCard("alias")
                    }
                }
                relationLabel(session.frame.value(named: "alias") != nil
                              ? "Both references reach one object"
                              : session.frame.value(named: "first") != nil
                              ? "first reaches object 01" : "Waiting for object references",
                              color: InstrumentPalette.actionAmber)
                variableCard(name: "object 01.Value", title: "Counter object 01 · Value",
                             color: accent, detail: "Mutation through alias is visible through first")
            }
            variableCard(name: "copy", title: "copy · int", color: InstrumentPalette.spectrum,
                         detail: "Independent storage — changes stay here")
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: session.completedSteps)
    }

    private func relationLabel(_ text: String, color: Color) -> some View {
        Label(text, systemImage: "arrow.down")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func referenceCard(_ name: String) -> some View {
        variableCard(name: name, title: name, color: InstrumentPalette.spectrum,
                     detail: "Counter reference")
    }

    private func variableCard(name: String, title: String, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
            Text(value(name)).font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(InstrumentPalette.displayInk)
                .monospacedDigit().contentTransition(.numericText())
            Text(detail).font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(InstrumentPalette.canvas, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demo.code.value.\(name)")
    }

    private var loopDiagram: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Three elements · valid indices 0, 1, 2")
                .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 8) { ForEach(0..<3) { arrayCell($0) } }
            } else {
                HStack(spacing: 8) { ForEach(0..<3) { arrayCell($0) } }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RUNNING SUM").font(.system(.caption, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                    Text(value("sum"))
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit().foregroundStyle(InstrumentPalette.actionAmber)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("demo.code.sum")
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("i < 3").font(.system(.callout, design: .monospaced, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(loopCondition).font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(session.completedSteps >= 9 ? "The boundary stops the loop. No a[3] read." : "Amber marks the current array element.")
                .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: session.completedSteps)
    }

    private func arrayCell(_ index: Int) -> some View {
        let active = session.frame.activeArrayIndex == index
        let color = active ? InstrumentPalette.actionAmber : accent
        return VStack(spacing: 6) {
            Text("a[\(index)]").font(.system(.caption, design: .monospaced, weight: .semibold))
            Text(value("a[\(index)]"))
                .font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
            Text(active ? "READ HERE" : "element \(index)")
                .font(.system(.caption2, design: .monospaced))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(InstrumentPalette.canvas, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(active ? 0.8 : 0.2), lineWidth: active ? 2 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("demo.code.array.\(index)")
    }

    private var loopCondition: String {
        if let index = session.frame.value(named: "i") {
            return "i = \(index.display) · \(index == .integer(3) ? "false" : "true")"
        }
        return session.isComplete || session.completedSteps >= 10 ? "loop finished" : "waiting for i"
    }

    private var console: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Console", systemImage: "terminal").font(.system(.caption, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk)
            Text(session.frame.console.isEmpty ? "Waiting for print…" : session.frame.console.joined(separator: "\n"))
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(session.frame.console.isEmpty ? InstrumentPalette.secondaryInk : InstrumentPalette.actionAmber)
                .textSelection(.enabled)
                .accessibilityIdentifier("demo.code.console")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(InstrumentPalette.canvas, in: .rect(cornerRadius: 12))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    LabAction(title: "Reset", symbol: "arrow.counterclockwise", accent: accent) {
                        onInteraction()
                        resetTrace()
                        CFeedback.selection()
                    }.accessibilityIdentifier("demo.code.reset")
                    LabAction(title: session.isComplete ? "Complete" : "Next event",
                              symbol: session.isComplete ? "checkmark" : "forward.frame.fill",
                              accent: InstrumentPalette.actionAmber) {
                        onInteraction()
                        manualSnapshot = true
                        if session.advance() { CFeedback.event() }
                    }
                    .disabled(session.isComplete)
                    .accessibilityIdentifier("demo.code.next")
                }
            }
            InstrumentParameterStepper("Starting integer", value: Binding(
                get: { seed },
                set: { value in
                    onInteraction()
                    seed = value
                    resetTrace()
                    CFeedback.selection()
                }), in: -12...12, unit: "")
                .accessibilityIdentifier("demo.code.seed")
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(ProgrammingLanguage.allCases) { choice in
                        Button {
                            onInteraction()
                            language = choice
                            resetTrace()
                            CFeedback.selection()
                        } label: {
                            Label(choice.rawValue, systemImage: language == choice ? "checkmark.circle.fill" : "circle")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                        .tint(choice == .c ? InstrumentPalette.actionCyan : InstrumentPalette.spectrum)
                        .instrumentControlOwnsTouches(identifier: "demo.code.\(choice.rawValue)")
                        .accessibilityAddTraits(language == choice ? .isSelected : [])
                        .accessibilityIdentifier(choice == .c ? "demo.code.language.c" : "demo.code.language.csharp")
                    }
                }
            }
        }
    }

    private var sourceTrace: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(language.rawValue) · statement trace")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(session.codeLines.enumerated()), id: \.offset) { index, line in
                            let number = index + 1
                            let executed = session.frame.line == number
                            let next = session.nextLine == number
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(executed ? "●" : next ? "→" : " ").frame(width: 12)
                                    .foregroundStyle(executed ? InstrumentPalette.actionAmber : accent)
                                Text("\(number)").frame(width: 22, alignment: .trailing)
                                    .foregroundStyle(InstrumentPalette.secondaryInk)
                                Text(line).foregroundStyle(executed ? InstrumentPalette.actionAmber : InstrumentPalette.displayInk)
                            }
                            .font(.system(.callout, design: .monospaced))
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .background(executed ? InstrumentPalette.actionAmber.opacity(0.1) : Color.clear, in: .rect(cornerRadius: 6))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(executed ? "Executed. " : next ? "Next. " : "")Line \(number): \(line)")
                            .accessibilityIdentifier(executed ? "demo.code.current-line" : "demo.code.line.\(number)")
                        }
                    }.fixedSize(horizontal: true, vertical: false)
                }
                .accessibilityIdentifier("demo.code.source")
                Text("Amber = last event · arrow = next event")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    private func value(_ name: String) -> String {
        session.frame.value(named: name)?.display ?? "—"
    }

    private func resetTrace() {
        session = LanguageSession(language: language, program: Self.program(for: step), initialValue: seed)
        manualSnapshot = true
        resumeProgress = 0
        resumeEvent = 0
    }

    private func synchronizeProgress() {
        guard !manualSnapshot else { return }
        let bounded = Self.bounded(progress)
        if bounded < resumeProgress {
            resumeProgress = 0
            resumeEvent = 0
        }
        let remaining = max(0.000_001, 1 - resumeProgress)
        let fraction = Self.bounded((bounded - resumeProgress) / remaining / 0.88)
        let events = min(session.totalSteps, resumeEvent + Int((fraction * Double(session.totalSteps - resumeEvent)).rounded(.down)))
        guard events != session.completedSteps else { return }
        var snapshot = LanguageSession(language: language, program: Self.program(for: step), initialValue: seed)
        for _ in 0..<events { snapshot.advance() }
        session = snapshot
    }
}
