import Foundation

public enum ProgrammingLanguage: String, CaseIterable, Identifiable, Sendable {
    case c = "C"
    case cSharp = "C#"
    public var id: String { rawValue }
    public var other: Self { self == .c ? .cSharp : .c }
}

public enum LanguageProgram: String, CaseIterable, Identifiable, Sendable {
    case division, aliasing, arraySum
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .division: "Division & types"
        case .aliasing: "Copy & alias"
        case .arraySum: "Array & loop"
        }
    }
    public var subtitle: String {
        switch self {
        case .division: "Change the operands; watch the result type."
        case .aliasing: "One object can have two ways to reach it."
        case .arraySum: "Visit three elements and build a running sum."
        }
    }
}

public enum LanguageValue: Equatable, Sendable {
    case integer(Int32)
    case real(Double)
    case pointer(address: UInt64, target: String)
    case reference(object: String)

    public var display: String {
        switch self {
        case .integer(let value): String(value)
        case .real(let value): String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
        case .pointer(let address, _): String(format: "0x%04llX", address)
        case .reference(let object): "→ \(object)"
        }
    }

    public var target: String? {
        switch self {
        case .pointer(_, let target): target
        case .reference(let object): object
        default: nil
        }
    }

    /// Deliberate teaching ABI: 8-bit bytes, 32-bit two's-complement int,
    /// binary64 double and 64-bit pointer, all little-endian. Not a C guarantee.
    public var modeledBytes: [UInt8] {
        switch self {
        case .integer(let value): Self.bytes(UInt64(UInt32(bitPattern: value)), count: 4)
        case .real(let value): Self.bytes(value.bitPattern, count: 8)
        case .pointer(let address, _): Self.bytes(address, count: 8)
        case .reference: []
        }
    }

    private static func bytes(_ bits: UInt64, count: Int) -> [UInt8] {
        (0..<count).map { UInt8(truncatingIfNeeded: bits >> ($0 * 8)) }
    }
}

public struct LanguageVariable: Identifiable, Equatable, Sendable {
    public let name: String
    public let type: String
    public let location: String
    public let value: LanguageValue
    public var id: String { name }
    public init(name: String, type: String, location: String, value: LanguageValue) {
        self.name = name
        self.type = type
        self.location = location
        self.value = value
    }
}

public struct LanguageFrame: Equatable, Sendable {
    /// The last executed source line, one-based. A loop header can recur.
    public let line: Int?
    public let explanation: String
    public let variables: [LanguageVariable]
    public let console: [String]
    public let activeArrayIndex: Int?

    public func value(named name: String) -> LanguageValue? {
        variables.first { $0.name == name }?.value
    }
}

/// A deterministic walkthrough of the displayed examples; this is not a
/// parser, compiler, runtime, debugger or arbitrary-code execution environment.
public struct LanguageSession: Equatable, Sendable {
    public let language: ProgrammingLanguage
    public let program: LanguageProgram
    public let initialValue: Int
    public private(set) var completedSteps = 0
    private let frames: [LanguageFrame]

    public init(language: ProgrammingLanguage = .c, program: LanguageProgram = .division, initialValue: Int = 7) {
        self.language = language
        self.program = program
        let boundedValue = min(12, max(-12, initialValue))
        self.initialValue = boundedValue
        self.frames = Self.makeFrames(language: language, program: program, seed: Int32(boundedValue))
    }

    public var totalSteps: Int { frames.count }
    public var isComplete: Bool { completedSteps == totalSteps }
    public var frame: LanguageFrame {
        completedSteps == 0
            ? LanguageFrame(line: nil, explanation: "Ready. Advance one statement or loop event and inspect its effect.", variables: [], console: [], activeArrayIndex: nil)
            : frames[completedSteps - 1]
    }
    public var nextLine: Int? { isComplete ? nil : frames[completedSteps].line }

    @discardableResult public mutating func advance() -> Bool {
        guard !isComplete else { return false }
        completedSteps += 1
        return true
    }

    public mutating func reset() { completedSteps = 0 }

    public var codeLines: [String] {
        let n = initialValue
        let body: [String]
        switch (language, program) {
        case (.c, .division):
            body = ["int n = \(n);", "int q = n / 2;", "double trap = n / 2;", "double real = n / 2.0;", "printf(\"%d %.2f %.2f\\n\", q, trap, real);"]
        case (.cSharp, .division):
            body = ["int n = \(n);", "int q = n / 2;", "double trap = n / 2;", "double real = n / 2.0;", "Console.WriteLine(FormattableString.Invariant($\"{q} {trap:F2} {real:F2}\"));"]
        case (.c, .aliasing):
            body = ["int value = \(n);", "int copy = value;", "int *p = &value;", "*p += 3;", "copy += 1;", "printf(\"%d %d\\n\", value, copy);"]
        case (.cSharp, .aliasing):
            body = ["var first = new Counter { Value = \(n) };", "var alias = first;", "int copy = first.Value;", "alias.Value += 3;", "copy += 1;", "Console.WriteLine($\"{first.Value} {copy}\");", "class Counter { public int Value; }"]
        case (.c, .arraySum):
            body = ["int a[3] = {\(n), \(n + 1), \(n + 2)};", "int sum = 0;", "for (int i = 0; i < 3; i++) {", "    sum += a[i];", "}", "printf(\"%d\\n\", sum);"]
        case (.cSharp, .arraySum):
            body = ["int[] a = {\(n), \(n + 1), \(n + 2)};", "int sum = 0;", "for (int i = 0; i < a.Length; i++) {", "    sum += a[i];", "}", "Console.WriteLine(sum);"]
        }
        return language == .c
            ? ["#include <stdio.h>", "int main(void) {"] + body.map { "    " + $0 } + ["    return 0;", "}"]
            : ["using System;"] + body
    }

    public var code: String { codeLines.joined(separator: "\n") }

    private static func makeFrames(language: ProgrammingLanguage, program: LanguageProgram, seed: Int32) -> [LanguageFrame] {
        var variables: [LanguageVariable] = []
        var result: [LanguageFrame] = []
        func put(_ name: String, _ type: String, _ value: LanguageValue, _ address: UInt64) {
            let location = language == .c ? String(format: "0x%04llX", address) : "local value"
            let variable = LanguageVariable(name: name, type: type, location: location, value: value)
            if let index = variables.firstIndex(where: { $0.name == name }) { variables[index] = variable }
            else { variables.append(variable) }
        }
        func reference(_ name: String, _ type: String, _ object: String) {
            variables.append(LanguageVariable(name: name, type: type, location: "local reference", value: .reference(object: object)))
        }
        func record(_ line: Int, _ text: String, console: [String] = [], arrayIndex: Int? = nil) {
            result.append(LanguageFrame(line: line, explanation: text, variables: variables, console: console, activeArrayIndex: arrayIndex))
        }

        switch program {
        case .division:
            put("n", "int", .integer(seed), 0x1000)
            record(1, "n holds the starting integer \(seed).")
            put("q", "int", .integer(seed / 2), 0x1004)
            record(2, "Both operands are integers: \(seed) / 2 = \(seed / 2), truncating toward zero.")
            put("trap", "double", .real(Double(seed / 2)), 0x1008)
            record(3, "The division happens first. Assigning its integer result to double cannot recover the fraction.")
            put("real", "double", .real(Double(seed) / 2), 0x1010)
            record(4, "The 2.0 operand makes this floating-point division: \(LanguageValue.real(Double(seed) / 2).display).")
            record(5, "The console displays q, trap and real. Their expression types explain the difference.", console: ["\(seed / 2) \(LanguageValue.real(Double(seed / 2)).display) \(LanguageValue.real(Double(seed) / 2).display)"])
        case .aliasing:
            if language == .c {
                put("value", "int", .integer(seed), 0x1000)
                record(1, "value is one modeled integer object.")
                put("copy", "int", .integer(seed), 0x1004)
                record(2, "copy receives the numeric value. It has independent storage.")
                put("p", "int *", .pointer(address: 0x1000, target: "value"), 0x1008)
                record(3, "&value obtains its address. p points to value; *p denotes that object.")
                put("value", "int", .integer(seed + 3), 0x1000)
                record(4, "Writing through *p changes value to \(seed + 3). copy remains \(seed).")
                put("copy", "int", .integer(seed + 1), 0x1004)
                record(5, "Changing copy affects only copy. The pointer still targets value.")
            } else {
                reference("first", "Counter", "object 01")
                variables.append(LanguageVariable(name: "object 01.Value", type: "int field", location: "managed object 01", value: .integer(seed)))
                record(1, "A Counter object is created. first stores a reference to object 01.")
                reference("alias", "Counter", "object 01")
                record(2, "The reference is copied. first and alias reach the same Counter object.")
                put("copy", "int", .integer(seed), 0)
                record(3, "copy receives an int value, separate from the Counter field.")
                if let i = variables.firstIndex(where: { $0.name == "object 01.Value" }) {
                    variables[i] = LanguageVariable(name: "object 01.Value", type: "int field", location: "managed object 01", value: .integer(seed + 3))
                }
                record(4, "Mutation through alias changes the shared field; first sees \(seed + 3) too.")
                put("copy", "int", .integer(seed + 1), 0)
                record(5, "The int copy changes independently. This example uses a class, a reference type.")
            }
            record(6, "Shared access and independent copying produce different final values.", console: ["\(seed + 3) \(seed + 1)"])
        case .arraySum:
            if language == .cSharp { reference("a", "int[]", "array 01") }
            for i in 0..<3 {
                let name = "a[\(i)]"
                let location = language == .c ? String(format: "0x%04llX", UInt64(0x1000 + i * 4)) : "array 01 element \(i)"
                variables.append(LanguageVariable(name: name, type: "int", location: location, value: .integer(seed + Int32(i))))
            }
            record(1, "Three elements are initialized. Valid indices are 0, 1 and 2.")
            var sum: Int32 = 0
            put("sum", "int", .integer(sum), 0x100C)
            record(2, "The running sum begins at zero.")
            for i in 0..<3 {
                put("i", "int", .integer(Int32(i)), 0x1010)
                record(3, i == 0 ? "Initialize i = 0, then test 0 < 3: true." : "Increment i to \(i), then test \(i) < 3: true.", arrayIndex: i)
                let previous = sum
                sum += seed + Int32(i)
                put("sum", "int", .integer(sum), 0x100C)
                record(4, "Read a[\(i)] = \(seed + Int32(i)): sum becomes \(previous) + \(seed + Int32(i)) = \(sum).", arrayIndex: i)
            }
            put("i", "int", .integer(3), 0x1010)
            record(3, "Increment i to 3. The test 3 < 3 is false; no a[3] access occurs.")
            variables.removeAll { $0.name == "i" }
            record(6, "The loop ends. Its local i leaves scope; the three elements sum to \(sum).", console: [String(sum)])
        }
        let offset = language == .c ? 2 : 1
        result = result.map { frame in
            LanguageFrame(line: frame.line.map { $0 + offset }, explanation: frame.explanation, variables: frame.variables, console: frame.console, activeArrayIndex: frame.activeArrayIndex)
        }
        if language == .c, let final = result.last {
            let returnLine = (program == .division ? 5 : 6) + 3
            result.append(LanguageFrame(line: returnLine, explanation: "return 0 ends main with a success status. The display retains the last observed values for review; local objects have ended their lifetimes.", variables: final.variables, console: final.console, activeArrayIndex: nil))
        }
        return result
    }
}
