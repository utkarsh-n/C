import XCTest
@testable import CCore

final class LanguageTests: XCTestCase {
    private func finish(_ session: inout LanguageSession) {
        while session.advance() {}
    }

    func testNegativeIntegerDivisionTruncatesBeforeAssignmentToDouble() {
        for language in ProgrammingLanguage.allCases {
            var trace = LanguageSession(language: language, program: .division, initialValue: -7)
            finish(&trace)
            XCTAssertEqual(trace.frame.value(named: "q"), .integer(-3))
            XCTAssertEqual(trace.frame.value(named: "trap"), .real(-3))
            XCTAssertEqual(trace.frame.value(named: "real"), .real(-3.5))
            XCTAssertEqual(trace.frame.console, ["-3 -3.00 -3.50"])
        }
    }

    func testPointerMutatesTargetButNotIndependentCopy() {
        var trace = LanguageSession(program: .aliasing, initialValue: 7)
        for _ in 0..<3 { trace.advance() }
        XCTAssertEqual(trace.frame.value(named: "p"), .pointer(address: 0x1000, target: "value"))
        XCTAssertEqual(trace.frame.value(named: "value"), .integer(7))
        XCTAssertEqual(trace.frame.value(named: "copy"), .integer(7))
        trace.advance()
        XCTAssertEqual(trace.frame.value(named: "value"), .integer(10))
        XCTAssertEqual(trace.frame.value(named: "copy"), .integer(7))
        XCTAssertEqual(trace.frame.value(named: "p")?.target, "value")
        finish(&trace)
        XCTAssertEqual(trace.frame.value(named: "copy"), .integer(8))
        XCTAssertEqual(trace.frame.console, ["10 8"])
    }

    func testCSharpReferenceAliasesShareOneObject() {
        var trace = LanguageSession(language: .cSharp, program: .aliasing, initialValue: 7)
        trace.advance()
        trace.advance()
        XCTAssertEqual(trace.frame.value(named: "first"), .reference(object: "object 01"))
        XCTAssertEqual(trace.frame.value(named: "alias"), .reference(object: "object 01"))
        trace.advance()
        trace.advance()
        XCTAssertEqual(trace.frame.value(named: "object 01.Value"), .integer(10))
        XCTAssertEqual(trace.frame.value(named: "copy"), .integer(7))
        finish(&trace)
        XCTAssertEqual(trace.frame.console, ["10 8"])
    }

    func testLoopChecksBoundsAndLeavesLoopLocalScope() {
        for language in ProgrammingLanguage.allCases {
            var trace = LanguageSession(language: language, program: .arraySum, initialValue: 7)
            var additions: [Int32] = []
            var visited: [Int] = []
            while trace.advance() {
                if let index = trace.frame.activeArrayIndex { visited.append(index) }
                if trace.frame.line == (language == .c ? 6 : 5), case .integer(let sum)? = trace.frame.value(named: "sum") {
                    additions.append(sum)
                }
            }
            XCTAssertEqual(visited, [0, 0, 1, 1, 2, 2])
            XCTAssertEqual(additions, [7, 15, 24])
            XCTAssertEqual(trace.frame.console, ["24"])
            XCTAssertNil(trace.frame.value(named: "i"))
            XCTAssertNil(trace.frame.value(named: "a[3]"))
        }
    }

    func testArrayCellsHaveContiguousModeledAddresses() {
        var trace = LanguageSession(program: .arraySum)
        trace.advance()
        XCTAssertEqual(trace.frame.variables.map(\.location), ["0x1000", "0x1004", "0x1008"])
    }

    func testModeledBytesAreLittleEndianAndPreserveNegativeSignBits() {
        XCTAssertEqual(LanguageValue.integer(-7).modeledBytes, [0xF9, 0xFF, 0xFF, 0xFF])
        XCTAssertEqual(LanguageValue.integer(256).modeledBytes, [0x00, 0x01, 0x00, 0x00])
        XCTAssertEqual(LanguageValue.real(3.5).modeledBytes, [0, 0, 0, 0, 0, 0, 0x0C, 0x40])
        XCTAssertEqual(LanguageValue.pointer(address: 0x1000, target: "value").modeledBytes, [0x00, 0x10, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(LanguageValue.reference(object: "object 01").modeledBytes, [])
    }

    func testResetRestoresInitialFrameAndCompleteTraceCannotAdvance() {
        var trace = LanguageSession(program: .arraySum)
        let initial = trace
        finish(&trace)
        let final = trace
        XCTAssertFalse(trace.advance())
        XCTAssertEqual(trace, final)
        XCTAssertNil(trace.nextLine)
        trace.reset()
        XCTAssertEqual(trace, initial)
        XCTAssertEqual(trace.nextLine, 3)
    }

    func testAllLineHighlightsMatchDisplayedCodeAndOutputsAcrossInputs() {
        for language in ProgrammingLanguage.allCases {
            for program in LanguageProgram.allCases {
                for seed in -12...12 {
                    var trace = LanguageSession(language: language, program: program, initialValue: seed)
                    var steps = 0
                    while trace.advance() {
                        steps += 1
                        let line = try! XCTUnwrap(trace.frame.line)
                        XCTAssertTrue((1...trace.codeLines.count).contains(line))
                    }
                    XCTAssertEqual(steps, trace.totalSteps)
                    XCTAssertTrue(trace.isComplete)
                    switch program {
                    case .division:
                        XCTAssertEqual(trace.frame.value(named: "q"), .integer(Int32(seed / 2)))
                        XCTAssertEqual(trace.frame.value(named: "real"), .real(Double(seed) / 2))
                    case .aliasing:
                        XCTAssertEqual(trace.frame.console, ["\(seed + 3) \(seed + 1)"])
                    case .arraySum:
                        XCTAssertEqual(trace.frame.value(named: "sum"), .integer(Int32(seed * 3 + 3)))
                    }
                }
            }
        }
    }

    func testExternalInitialValueIsBoundedWithoutOverflow() {
        XCTAssertEqual(LanguageSession(initialValue: Int.max).initialValue, 12)
        XCTAssertEqual(LanguageSession(initialValue: Int.min).initialValue, -12)
    }
}
