import Foundation

/// The lab uses dimensionless x; trigonometric arguments are in radians.
public enum CIntegrand: String, CaseIterable, Identifiable, Sendable {
    case linear, square, sine, exponential

    public var id: String { rawValue }

    public var formula: String {
        switch self {
        case .linear: "2x"
        case .square: "x²"
        case .sine: "sin x"
        case .exponential: "eˣ"
        }
    }

    public var primitiveFormula: String {
        switch self {
        case .linear: "x²"
        case .square: "x³ / 3"
        case .sine: "−cos x"
        case .exponential: "eˣ"
        }
    }

    public var cExpression: String {
        switch self {
        case .linear: "2.0 * x"
        case .square: "x * x"
        case .sine: "sin(x)"
        case .exponential: "exp(x)"
        }
    }

    public func value(at x: Double) -> Double {
        switch self {
        case .linear: 2 * x
        case .square: x * x
        case .sine: sin(x)
        case .exponential: exp(x)
        }
    }

    /// Derivative of the integrand f, as distinct from F′ = f.
    public func derivative(at x: Double) -> Double {
        switch self {
        case .linear: 2
        case .square: 2 * x
        case .sine: cos(x)
        case .exponential: exp(x)
        }
    }

    public func primitive(at x: Double, constant: Double = 0) -> Double {
        let base: Double = switch self {
        case .linear: x * x
        case .square: x * x * x / 3
        case .sine: -cos(x)
        case .exponential: exp(x)
        }
        return base + constant
    }

    /// A known point F(x₀) = y₀ selects one member of the antiderivative family.
    public func constant(forValue y: Double, at x: Double) -> Double {
        y - primitive(at: x)
    }

    public func definiteIntegral(from a: Double, to b: Double) -> Double {
        primitive(at: b) - primitive(at: a)
    }
}

public enum IntegrationRule: String, CaseIterable, Identifiable, Sendable {
    case midpoint, trapezoid, simpson

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .midpoint: "Midpoint"
        case .trapezoid: "Trapezoid"
        case .simpson: "Simpson"
        }
    }
    public var shapeName: String {
        switch self {
        case .midpoint: "rectangles"
        case .trapezoid: "trapezoids"
        case .simpson: "quadratic pairs"
        }
    }
    public var explanation: String {
        switch self {
        case .midpoint:
            "Use the height at each interval’s center. Add signed rectangle areas: height × width."
        case .trapezoid:
            "Join adjacent sample heights with straight lines. Each signed area uses the average endpoint height."
        case .simpson:
            "Fit a quadratic through each pair of intervals. Endpoint and midpoint weights are 1, 4, 1. The interval count must be even."
        }
    }
}

/// A geometric piece of the chosen numerical approximation.
public struct IntegrationSlice: Identifiable, Sendable, Equatable {
    public let id: Int
    public let start: Double
    public let end: Double
    public let startHeight: Double
    public let middleHeight: Double
    public let endHeight: Double
    public let signedArea: Double
    public let rule: IntegrationRule

    public func height(atFraction fraction: Double) -> Double {
        let t = min(1, max(0, fraction))
        switch rule {
        case .midpoint: return middleHeight
        case .trapezoid: return startHeight + (endHeight - startHeight) * t
        case .simpson:
            // Lagrange interpolation at t = 0, 1/2, 1.
            return 2 * (t - 0.5) * (t - 1) * startHeight
                - 4 * t * (t - 1) * middleHeight
                + 2 * t * (t - 0.5) * endHeight
        }
    }
}

public struct IntegrationResult: Sendable, Equatable {
    public let lower: Double
    public let upper: Double
    public let subdivisions: Int
    public let estimate: Double
    public let exact: Double
    public let evaluations: Int
    public let slices: [IntegrationSlice]
    public var absoluteError: Double { abs(estimate - exact) }
}

public struct ConvergenceSample: Sendable, Identifiable, Equatable {
    public let subdivisions: Int
    public let estimate: Double
    public let error: Double
    public var id: Int { subdivisions }
}

public enum CalculusLab {
    public static let xRange: ClosedRange<Double> = -3...3
    public static let constantRange: ClosedRange<Double> = -5...5
    public static let subdivisionRange = 2...128

    public static func boundedX(_ x: Double) -> Double {
        x.isFinite ? min(xRange.upperBound, max(xRange.lowerBound, x)) : 0
    }

    public static func normalizedSubdivisions(_ requested: Int, rule: IntegrationRule) -> Int {
        let bounded = min(subdivisionRange.upperBound, max(subdivisionRange.lowerBound, requested))
        return rule == .simpson && !bounded.isMultiple(of: 2) ? bounded + 1 : bounded
    }

    public static func integrate(
        _ function: CIntegrand,
        from requestedA: Double,
        to requestedB: Double,
        subdivisions requestedCount: Int,
        rule: IntegrationRule
    ) -> IntegrationResult {
        let a = boundedX(requestedA)
        let b = boundedX(requestedB)
        let n = normalizedSubdivisions(requestedCount, rule: rule)
        let h = (b - a) / Double(n)
        let gridHeights = rule == .midpoint ? [] : (0...n).map {
            function.value(at: a + Double($0) * h)
        }
        var slices: [IntegrationSlice] = []
        slices.reserveCapacity(rule == .simpson ? n / 2 : n)

        for i in stride(from: 0, to: n, by: rule == .simpson ? 2 : 1) {
            let start = a + Double(i) * h
            let end = a + Double(i + (rule == .simpson ? 2 : 1)) * h
            let middle = (start + end) / 2
            let y0: Double
            let ym: Double
            let y1: Double
            switch rule {
            case .midpoint:
                ym = function.value(at: middle)
                y0 = ym
                y1 = ym
            case .trapezoid:
                y0 = gridHeights[i]
                y1 = gridHeights[i + 1]
                ym = (y0 + y1) / 2
            case .simpson:
                y0 = gridHeights[i]
                ym = gridHeights[i + 1]
                y1 = gridHeights[i + 2]
            }
            let width = end - start
            let area: Double = switch rule {
            case .midpoint: width * ym
            case .trapezoid: width * (y0 + y1) / 2
            case .simpson: width * (y0 + 4 * ym + y1) / 6
            }
            slices.append(IntegrationSlice(
                id: i, start: start, end: end, startHeight: y0,
                middleHeight: ym, endHeight: y1, signedArea: area, rule: rule
            ))
        }
        // Compensated accumulation reduces cancellation for mixed-sign areas.
        var sum = 0.0
        var correction = 0.0
        for slice in slices {
            let adjusted = slice.signedArea - correction
            let next = sum + adjusted
            correction = (next - sum) - adjusted
            sum = next
        }
        let evaluations = rule == .midpoint ? n : n + 1
        return IntegrationResult(
            lower: a, upper: b, subdivisions: n, estimate: sum,
            exact: function.definiteIntegral(from: a, to: b),
            evaluations: evaluations, slices: slices
        )
    }

    public static func convergence(
        _ function: CIntegrand, from a: Double, to b: Double, rule: IntegrationRule
    ) -> [ConvergenceSample] {
        [2, 4, 8, 16, 32, 64, 128].map { count in
            let result = integrate(function, from: a, to: b, subdivisions: count, rule: rule)
            return ConvergenceSample(subdivisions: count, estimate: result.estimate, error: result.absoluteError)
        }
    }

    /// Complete C99 source for the displayed bounded problem.
    public static func cSource(
        _ function: CIntegrand, from a: Double, to b: Double,
        subdivisions: Int, rule: IntegrationRule
    ) -> String {
        let result = integrate(function, from: a, to: b, subdivisions: subdivisions, rule: rule)
        let loop: String
        let scale: String
        switch rule {
        case .midpoint:
            loop = """
                for (int i = 0; i < n; ++i) {
                    double x = a + (i + 0.5) * h;
                    sum += f(x);
                }
            """
            scale = "sum * h"
        case .trapezoid:
            loop = """
                sum = (f(a) + f(b)) / 2.0;
                for (int i = 1; i < n; ++i) {
                    sum += f(a + i * h);
                }
            """
            scale = "sum * h"
        case .simpson:
            loop = """
                // n is even: endpoint weights 1, then 4, 2, ...
                sum = f(a) + f(b);
                for (int i = 1; i < n; ++i) {
                    int weight = (i % 2 == 1) ? 4 : 2;
                    sum += weight * f(a + i * h);
                }
            """
            scale = "sum * h / 3.0"
        }
        let body = loop.split(separator: "\n", omittingEmptySubsequences: false).map { "    " + $0 }.joined(separator: "\n")
        return """
        #include <math.h>
        #include <stdio.h>

        double f(double x) {
            return \(function.cExpression);
        }

        int main(void) {
            const double a = \(String(format: "%.17g", result.lower));
            const double b = \(String(format: "%.17g", result.upper));
            const int n = \(result.subdivisions);
            const double h = (b - a) / n;
            double sum = 0.0;
        \(body)
            printf("%.9f\\n", \(scale));
            return 0;
        }
        """
    }
}
