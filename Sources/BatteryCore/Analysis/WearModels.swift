import Foundation

/// Linear calendar aging anchored at 100% on day 0: `health = 100 − rate·t`.
///
/// Works from a **single measurement** (the day-one estimate). With more points it
/// least-squares-fits the rate while keeping the (0, 100) anchor.
public struct LinearCalendarModel: WearModel {
    public init() {}
    public let name = "Linear calendar"
    public let minimumPoints = 1

    public func fit(_ points: [WearPoint]) -> FittedWearModel? {
        let pts = points.filter { $0.ageDays > 0 }
        guard !pts.isEmpty else { return nil }
        // Minimise Σ(100 − r·t − h)²  →  r = Σ t·(100−h) / Σ t²
        let num = pts.reduce(0.0) { $0 + $1.ageDays * (100 - $1.healthPercent) }
        let den = pts.reduce(0.0) { $0 + $1.ageDays * $1.ageDays }
        guard den > 0 else { return nil }
        let rate = num / den
        let predict: @Sendable (Double) -> Double = { t in 100 - rate * t }
        let r2 = LeastSquares.rSquared(observed: pts.map(\.healthPercent),
                                       predicted: pts.map { predict($0.ageDays) })
        return FittedWearModel(
            name: name, r2: r2,
            predictHealth: predict,
            ageDays: { target in rate > 0 ? (100 - target) / rate : nil }
        )
    }
}

/// Free linear regression: `health = a + b·t` (intercept not pinned to 100).
/// Captures a battery whose reported health didn't start exactly at 100.
public struct LinearRegressionModel: WearModel {
    public init() {}
    public let name = "Linear regression"
    public let minimumPoints = 2

    public func fit(_ points: [WearPoint]) -> FittedWearModel? {
        let pts = points
        guard pts.count >= minimumPoints else { return nil }
        let n = Double(pts.count)
        let sx = pts.reduce(0) { $0 + $1.ageDays }
        let sy = pts.reduce(0) { $0 + $1.healthPercent }
        let sxx = pts.reduce(0) { $0 + $1.ageDays * $1.ageDays }
        let sxy = pts.reduce(0) { $0 + $1.ageDays * $1.healthPercent }
        let denom = n * sxx - sx * sx
        guard abs(denom) > 1e-9 else { return nil }
        let b = (n * sxy - sx * sy) / denom   // slope (negative = degrading)
        let a = (sy - b * sx) / n             // intercept
        let predict: @Sendable (Double) -> Double = { t in a + b * t }
        let r2 = LeastSquares.rSquared(observed: pts.map(\.healthPercent),
                                       predicted: pts.map { predict($0.ageDays) })
        return FittedWearModel(
            name: name, r2: r2,
            predictHealth: predict,
            ageDays: { target in b < 0 ? (target - a) / b : nil }
        )
    }
}

/// Square-root calendar aging anchored at 100%: `health = 100 − a·√t`.
///
/// The textbook shape for lithium-ion calendar fade (fast early, decelerating). Most
/// meaningful with several points spread over time.
public struct SqrtCalendarModel: WearModel {
    public init() {}
    public let name = "√t calendar aging"
    public let minimumPoints = 2

    public func fit(_ points: [WearPoint]) -> FittedWearModel? {
        let pts = points.filter { $0.ageDays > 0 }
        guard pts.count >= minimumPoints else { return nil }
        // Minimise Σ(100 − a·√t − h)²  →  a = Σ √t·(100−h) / Σ t
        let num = pts.reduce(0.0) { $0 + sqrt($1.ageDays) * (100 - $1.healthPercent) }
        let den = pts.reduce(0.0) { $0 + $1.ageDays }
        guard den > 0 else { return nil }
        let a = num / den
        let predict: @Sendable (Double) -> Double = { t in 100 - a * sqrt(max(0, t)) }
        let r2 = LeastSquares.rSquared(observed: pts.map(\.healthPercent),
                                       predicted: pts.map { predict($0.ageDays) })
        return FittedWearModel(
            name: name, r2: r2,
            predictHealth: predict,
            ageDays: { target in
                guard a > 0 else { return nil }
                let root = (100 - target) / a
                return root * root
            }
        )
    }
}
