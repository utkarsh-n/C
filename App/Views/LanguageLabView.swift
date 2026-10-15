import SwiftUI
import CCore

struct LanguageLabView: View {
    @State private var language: ProgrammingLanguage = .c
    @State private var program: LanguageProgram = .division
    @State private var seed = 7
    @State private var session = LanguageSession()

    private var accent: Color { language == .c ? InstrumentPalette.actionCyan : InstrumentPalette.spectrum }
    private var seedBinding: Binding<Int> {
        Binding(get: { seed }, set: { value in
            seed = value
            rebuild()
            CFeedback.selection()
        })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LabHeader(eyebrow: "02 / Language", title: language == .c ? "C is a language." : "Meet C#.", subtitle: "Follow a statement. Inspect its values. See what changes.")
                controls
                execution
                memory
                console
                lessons
                comparison
                LabNote(title: "Guided execution model", text: "These fixed examples advance through statements and loop events. This app does not compile or run arbitrary C or C#. Changing the starting integer resets the trace. Headers and declarations set up each example; final values remain visible for review.")
                references
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(InstrumentDesignBackground())
        .onChange(of: language) { _, _ in rebuild(); CFeedback.selection() }
        .onChange(of: program) { _, _ in rebuild(); CFeedback.selection() }
    }

    private var controls: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Programming language", selection: $language) {
                    ForEach(ProgrammingLanguage.allCases) { language in Text(language.rawValue).tag(language) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("language.mode")
                Picker("Experiment", selection: $program) {
                    Text("Types").tag(LanguageProgram.division)
                    Text("Aliases").tag(LanguageProgram.aliasing)
                    Text("Loops").tag(LanguageProgram.arraySum)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("language.program")
                Text(program.title).font(.title3.weight(.semibold)).foregroundStyle(InstrumentPalette.displayInk)
                Text(program.subtitle).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                InstrumentParameterStepper("Starting integer", value: seedBinding, in: -12...12, unit: "")
                    .accessibilityIdentifier("language.seed")
            }
        }
    }

    private var execution: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    InstrumentMetricReadout("TRACE", value: "\(session.completedSteps)/\(session.totalSteps)", unit: "events", color: accent)
                    InstrumentMetricReadout("LINE", value: session.frame.line.map(String.init) ?? "—", unit: session.isComplete ? "finished" : "executed", color: InstrumentPalette.actionAmber)
                }
                HStack {
                    Text("\(language.rawValue) source").font(.system(.caption, design: .monospaced))
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                    Spacer()
                    ShareLink(item: session.code) {
                        Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44)
                    }.tint(accent).accessibilityLabel("Share \(language.rawValue) program")
                }
                sourceTrace
                Text(session.frame.explanation)
                    .font(.subheadline)
                    .foregroundStyle(InstrumentPalette.displayInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("language.state")
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        LabAction(title: "Reset", symbol: "arrow.counterclockwise", accent: accent) {
                            session.reset()
                            CFeedback.selection()
                        }
                        .accessibilityIdentifier("language.reset")
                        LabAction(title: session.isComplete ? "Complete" : "Next event", symbol: session.isComplete ? "checkmark" : "forward.frame.fill", accent: InstrumentPalette.actionAmber) {
                            if session.advance() { CFeedback.event() }
                        }
                        .disabled(session.isComplete)
                        .accessibilityIdentifier("language.next")
                    }
                }
                Text(session.isComplete ? "Trace complete. Reset or choose another experiment." : "Amber marks the last executed line; the arrow marks the next event.")
                    .font(.caption)
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    private var sourceTrace: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(session.codeLines.enumerated()), id: \.offset) { index, line in
                    sourceLine(index + 1, line)
                }
            }
            .padding(12)
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(Color(red: 0.022, green: 0.036, blue: 0.047), in: .rect(cornerRadius: 12))
        .accessibilityIdentifier("language.code")
    }

    private func sourceLine(_ number: Int, _ code: String) -> some View {
        let executed = number == session.frame.line
        let upcoming = number == session.nextLine
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(executed ? "●" : upcoming ? "→" : " ")
                .frame(width: 12)
                .foregroundStyle(executed ? InstrumentPalette.actionAmber : accent)
            Text(String(format: "%2d", number))
                .foregroundStyle(InstrumentPalette.secondaryInk)
            Text(code)
                .foregroundStyle(executed ? InstrumentPalette.actionAmber : InstrumentPalette.displayInk)
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .background(executed ? InstrumentPalette.actionAmber.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(executed ? "Last executed. " : upcoming ? "Next event. " : "")Line \(number): \(code)")
        .accessibilityIdentifier(executed ? "language.current-line" : "language.line.\(number)")
    }

    private var memory: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(language == .c ? "Memory bench" : "Values & object identity")
                    .font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                if session.frame.variables.isEmpty {
                    Text("No values yet. Advance the trace to create the first object.")
                        .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                } else {
                    ForEach(session.frame.variables) { variable in
                        memoryRow(variable)
                    }
                }
                Text(language == .c
                     ? "Teaching ABI: 8-bit bytes; 32-bit two’s-complement int; binary64 double; 64-bit pointer; little-endian. Addresses are illustrative. C does not require these sizes or this layout."
                     : "Object numbers identify shared objects in this model. They are not memory addresses or a .NET heap layout. C# int is a 32-bit value type; classes and arrays are reference types.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("language.memory")
    }

    private func memoryRow(_ variable: LanguageVariable) -> some View {
        let active = session.frame.activeArrayIndex.map { variable.name == "a[\($0)]" } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(variable.name).font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(active ? InstrumentPalette.actionAmber : accent)
                Spacer(minLength: 8)
                Text(variable.value.display).font(.system(.title3, design: .rounded, weight: .medium))
                    .monospacedDigit().foregroundStyle(InstrumentPalette.displayInk)
            }
            Text("\(variable.type) · \(variable.location)")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
            if let target = variable.value.target {
                Label("Targets \(target)", systemImage: "arrow.turn.down.right")
                    .font(.caption).foregroundStyle(InstrumentPalette.actionAmber)
            }
            if language == .c {
                ViewThatFits(in: .horizontal) {
                    byteLabels(variable.value.modeledBytes)
                    Text(variable.value.modeledBytes.map { String(format: "%02X", $0) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityLabel("Modeled bytes, lowest address first: \(variable.value.modeledBytes.map { String(format: "%02X", $0) }.joined(separator: ", "))")
            }
        }
        .padding(12)
        .background(InstrumentPalette.canvas, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? InstrumentPalette.actionAmber.opacity(0.5) : .white.opacity(0.06)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("language.variable.\(variable.name)")
    }

    private func byteLabels(_ bytes: [UInt8]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(bytes.enumerated()), id: \.offset) { _, value in
                Text(String(format: "%02X", value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .background(.white.opacity(0.04), in: .rect(cornerRadius: 5))
            }
        }
    }

    private var console: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Console", systemImage: "terminal").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                Text(session.frame.console.isEmpty ? "Waiting for output…" : session.frame.console.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(session.frame.console.isEmpty ? InstrumentPalette.secondaryInk : InstrumentPalette.actionAmber)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("language.console")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var lessons: some View {
        switch program {
        case .division:
            LabNote(title: "The expression chooses the arithmetic", text: "In C and C#, integer / integer discards the fraction toward zero. A double destination does not change that earlier operation. Use a floating operand such as 2.0. Try an odd negative starting value.", equation: "7 / 2 → 3     −7 / 2 → −3\n7 / 2.0 → 3.5")
        case .aliasing:
            LabNote(title: language == .c ? "Address, then dereference" : "A copied reference is an alias", text: language == .c ? "&value asks where value lives; *p names the object reached through p. An int assignment copies the value. Changing copy does not change value. These pointers remain valid while the local objects live." : "Assigning a Counter class variable copies its reference. Both variables reach one object, so field mutation is shared. Copying an int copies its value. A C# struct would have different value semantics.", equation: language == .c ? "p = &value     *p += 3" : "first → object 01 ← alias")
        case .arraySum:
            LabNote(title: "The boundary is part of the algorithm", text: "Three elements use indices 0 through 2. The condition is checked before each addition. i reaches 3 only for the failing test; the program never reads a[3]. C# checks array bounds at runtime. An out-of-range access in C is undefined behavior.", equation: "sum ← sum + a[i]    while i < 3")
        }
        if language == .cSharp {
            LabNote(title: "Managed memory & resource cleanup", text: ".NET can reclaim unreachable managed objects during garbage collection; timing is not deterministic. Resource cleanup is a separate concern. C# also supports pointers in unsafe contexts with additional rules. This lab uses ordinary managed references.")
        } else {
            LabNote(title: "C puts storage responsibilities in view", text: "These examples use automatic local objects. C also offers dynamically allocated storage through malloc and free. Pointer lifetime, bounds and valid access remain the programmer’s responsibility. The guided model stays within valid values and accesses.")
        }
    }

    private var comparison: some View {
        InstrumentContentPanel {
            DisclosureGroup("Compare with \(language.other.rawValue)") {
                CodeBlock(code: LanguageSession(language: language.other, program: program, initialValue: seed).code, language: language.other.rawValue)
                    .padding(.top, 12)
                Text(program == .aliasing ? "The C example reaches a local int with a pointer. The C# example reaches a Counter class with a managed reference. Their shared mutation result is comparable; their storage and lifetime mechanisms differ." : "These examples perform the same arithmetic and loop operations with different library syntax.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk).padding(.top, 8)
            }
            .font(.subheadline).tint(accent)
            .foregroundStyle(InstrumentPalette.displayInk)
        }
    }

    private var references: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Read the source rules").font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                Link("WG14 C draft: types, pointers & division", destination: URL(string: "https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf")!)
                Link("Microsoft: C# arithmetic", destination: URL(string: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/arithmetic-operators")!)
                Link("Microsoft: reference types", destination: URL(string: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/reference-types")!)
                Link("Microsoft: C# array rules", destination: URL(string: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/arrays")!)
                Link("Microsoft: unsafe pointers", destination: URL(string: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code")!)
                Link("Microsoft: garbage collection", destination: URL(string: "https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals")!)
            }.font(.subheadline).tint(accent).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rebuild() {
        session = LanguageSession(language: language, program: program, initialValue: seed)
    }
}
