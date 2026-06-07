import Foundation

/// One measurement reduced to what the wear models need: how old the battery was and
/// how healthy it measured, plus an optional cycle count.
public struct WearPoint: Sendable, Hashable {
    public let ageDays: Double
    public let healthPercent: Double
    public let cycleCount: Int?

    public init(ageDays: Double, healthPercent: Double, cycleCount: Int? = nil) {
        self.ageDays = ageDays
        self.healthPercent = healthPercent
        self.cycleCount = cycleCount
    }
}

/// A model fitted to a set of points: can predict health at any age and invert to find
/// the age at which a threshold health is reached.
public struct FittedWearModel: Sendable {
    public let name: String
    public let r2: Double
    /// ageDays -> predicted health %.
    public let predictHealth: @Sendable (Double) -> Double
    /// Smallest ageDays at which predicted health == target, or nil if never / undefined.
    public let ageDays: @Sendable (_ atHealth: Double) -> Double?

    public init(name: String, r2: Double,
                predictHealth: @escaping @Sendable (Double) -> Double,
                ageDays: @escaping @Sendable (_ atHealth: Double) -> Double?) {
        self.name = name
        self.r2 = r2
        self.predictHealth = predictHealth
        self.ageDays = ageDays
    }
}

/// Strategy for modelling capacity fade over time. New models (e.g. calendar+cycle) can
/// be dropped into ``WearEstimator`` without touching callers.
public protocol WearModel: Sendable {
    var name: String { get }
    /// Minimum points required to fit.
    var minimumPoints: Int { get }
    /// Returns a fitted model, or nil if the data is insufficient/degenerate.
    func fit(_ points: [WearPoint]) -> FittedWearModel?
}

// MARK: - Shared least-squares helpers

enum LeastSquares {
    /// R² of predictions vs. observed.
    static func rSquared(observed: [Double], predicted: [Double]) -> Double {
        guard observed.count == predicted.count, observed.count > 0 else { return 0 }
        let mean = observed.reduce(0, +) / Double(observed.count)
        let ssTot = observed.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let ssRes = zip(observed, predicted).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        if ssTot == 0 { return ssRes == 0 ? 1 : 0 }
        return max(0, 1 - ssRes / ssTot)
    }
}
