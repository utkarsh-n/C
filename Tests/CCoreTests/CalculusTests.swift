import XCTest
@testable import CCore

final class CalculusTests: XCTestCase {
    func testPrimitiveFamilyHasTheSameDerivative() {
        let epsilon = 0.00001
        for function in CIntegrand.allCases {
            for x in [-2.4, -0.5, 0.0, 1.7, 2.8] {
                for constant in [-5.0, 0, 4.3] {
                    let numericalSlope = (
                        function.primitive(at: x + epsilon, constant: constant)
                        - function.primitive(at: x - epsilon, constant: constant)
                    ) / (2 * epsilon)
                    XCTAssertEqual(numericalSlope, function.value(at: x), accuracy: 0.000001)
                }
            }
        }
    }

    func testInitialConditionSelectsOneConstant() {
        for function in CIntegrand.allCases {
            let constant = function.constant(forValue: 2.75, at: 1.2)
            XCTAssertEqual(function.primitive(at: 1.2, constant: constant), 2.75, accuracy: 1e-12)
        }
    }

    func testConstantCancelsFromDefiniteIntegral() {
        for function in CIntegrand.allCases {
            let expected = function.definiteIntegral(from: -1, to: 2)
            let shiftedDifference = function.primitive(at: 2, constant: 3.4)
                - function.primitive(at: -1, constant: 3.4)
            XCTAssertEqual(shiftedDifference, expected, accuracy: 1e-12)
        }
    }

    func testPolynomialRulesMatchKnownIntegrals() {
        for rule in IntegrationRule.allCases {
            let linear = CalculusLab.integrate(.linear, from: -1, to: 2, subdivisions: 8, rule: rule)
            XCTAssertEqual(linear.estimate, 3, accuracy: 1e-12)
        }
        let square = CalculusLab.integrate(.square, from: 0, to: 3, subdivisions: 2, rule: .simpson)
        XCTAssertEqual(square.estimate, 9, accuracy: 1e-12)
    }

    func testSignedAreasAndReversedLimits() {
        for rule in IntegrationRule.allCases {
            let forward = CalculusLab.integrate(.sine, from: -2.5, to: 1.7, subdivisions: 32, rule: rule)
            let reverse = CalculusLab.integrate(.sine, from: 1.7, to: -2.5, subdivisions: 32, rule: rule)
            XCTAssertEqual(forward.estimate, -reverse.estimate, accuracy: 1e-12)
            XCTAssertEqual(forward.exact, -reverse.exact, accuracy: 1e-12)
            XCTAssertTrue(forward.slices.contains { $0.signedArea < 0 })
            XCTAssertTrue(forward.slices.contains { $0.signedArea > 0 })
        }
    }

    func testZeroIntervalHasZeroArea() {
        for rule in IntegrationRule.allCases {
            let result = CalculusLab.integrate(.exponential, from: 1.2, to: 1.2, subdivisions: 16, rule: rule)
            XCTAssertEqual(result.estimate, 0)
            XCTAssertEqual(result.exact, 0)
            XCTAssertTrue(result.slices.allSatisfy { $0.signedArea == 0 })
        }
    }

    func testSubdivisionsAndInputsAreBounded() {
        XCTAssertEqual(CalculusLab.normalizedSubdivisions(-100, rule: .midpoint), 2)
        XCTAssertEqual(CalculusLab.normalizedSubdivisions(100_000, rule: .trapezoid), 128)
        XCTAssertEqual(CalculusLab.normalizedSubdivisions(7, rule: .simpson), 8)
        XCTAssertEqual(CalculusLab.normalizedSubdivisions(127, rule: .simpson), 128)
        let result = CalculusLab.integrate(.square, from: -.infinity, to: 999, subdivisions: -1, rule: .simpson)
        XCTAssertEqual(result.lower, 0)
        XCTAssertEqual(result.upper, 3)
        XCTAssertEqual(result.subdivisions, 2)
        XCTAssertTrue(result.estimate.isFinite)
    }

    func testEachGeometryMatchesItsRuleAndArea() {
        for rule in IntegrationRule.allCases {
            let result = CalculusLab.integrate(.exponential, from: -1, to: 2, subdivisions: 6, rule: rule)
            XCTAssertEqual(result.slices.reduce(0) { $0 + $1.signedArea }, result.estimate, accuracy: 1e-12)
            for slice in result.slices {
                XCTAssertEqual(slice.height(atFraction: 0), slice.startHeight, accuracy: 1e-12)
                XCTAssertEqual(slice.height(atFraction: 0.5), slice.middleHeight, accuracy: 1e-12)
                XCTAssertEqual(slice.height(atFraction: 1), slice.endHeight, accuracy: 1e-12)
            }
            XCTAssertEqual(result.evaluations, rule == .midpoint ? 6 : 7)
            XCTAssertEqual(result.slices.count, rule == .simpson ? 3 : 6)
        }
    }

    func testRefinementReducesSmoothFunctionError() {
        for rule in IntegrationRule.allCases {
            let samples = CalculusLab.convergence(.exponential, from: 0, to: 2, rule: rule)
            XCTAssertEqual(samples.map(\.subdivisions), [2, 4, 8, 16, 32, 64, 128])
            for pair in zip(samples, samples.dropFirst()) {
                XCTAssertLessThan(pair.1.error, pair.0.error)
            }
            XCTAssertLessThan(samples.last!.error, 0.0002)
        }
    }

    func testGeneratedCProgramUsesEffectiveBoundsAndCount() {
        let source = CalculusLab.cSource(.sine, from: -100, to: 100, subdivisions: 7, rule: .simpson)
        XCTAssertTrue(source.contains("return sin(x);"))
        XCTAssertTrue(source.contains("const double a = -3;"))
        XCTAssertTrue(source.contains("const double b = 3;"))
        XCTAssertTrue(source.contains("const int n = 8;"))
        XCTAssertTrue(source.contains("sum * h / 3.0"))
        XCTAssertTrue(source.contains("printf(\"%.9f\\n\""))
    }
}
