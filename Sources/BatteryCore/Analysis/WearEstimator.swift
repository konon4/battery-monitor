import Foundation

/// The result of projecting battery wear forward.
public struct WearProjection: Sendable, Hashable {
    public let modelName: String
    public let sampleCount: Int
    public let currentHealthPercent: Double
    public let wearPercent: Double                 // 100 − currentHealth
    public let ratePerDay: Double                  // local degradation rate, %/day
    public let threshold: Double                   // end-of-life health, e.g. 80
    public let projectedDateToThreshold: Date?
    public let daysToThreshold: Double?
    public let r2: Double?
    public let confidence: Confidence

    public enum Confidence: String, Sendable { case low, medium, high }
}

/// Chooses the best-fitting ``WearModel`` for the available data and projects forward.
///
/// One measurement → linear-calendar day-one estimate (low confidence). As measurements
/// accumulate, richer models become eligible and the best fit (by R²) wins, with
/// confidence rising as the data spans more time.
public struct WearEstimator: Sendable {
    public let threshold: Double
    public let models: [any WearModel]

    public init(threshold: Double = 80, models: [any WearModel]? = nil) {
        self.threshold = threshold
        self.models = models ?? [LinearCalendarModel(), LinearRegressionModel(), SqrtCalendarModel()]
    }

    /// Build wear points from samples that carry a health reading, aged from `firstUseDate`.
    public static func points(from samples: [BatterySample], firstUseDate: Date) -> [WearPoint] {
        samples.compactMap { s in
            guard let h = s.healthPercent else { return nil }
            let age = s.timestamp.timeIntervalSince(firstUseDate) / 86_400.0
            guard age > 0 else { return nil }
            return WearPoint(ageDays: age, healthPercent: h, cycleCount: s.cycleCount)
        }.sorted { $0.ageDays < $1.ageDays }
    }

    /// Project wear. `anchorDate` (first-use date) maps model ages back to calendar dates.
    public func project(points: [WearPoint], anchorDate: Date?) -> WearProjection? {
        guard let latest = points.max(by: { $0.ageDays < $1.ageDays }) else { return nil }

        // Eligible models, best R² first (ties broken by simpler/earlier model).
        let fits = models
            .compactMap { model -> FittedWearModel? in
                points.count >= model.minimumPoints ? model.fit(points) : nil
            }
            .sorted { $0.r2 > $1.r2 }
        guard let best = fits.first else { return nil }

        // Local rate at the latest age (numerical derivative), reported as positive %/day.
        let dt = 1.0
        let rate = (best.predictHealth(latest.ageDays) - best.predictHealth(latest.ageDays + dt)) / dt

        let ageAtThreshold = best.ageDays(threshold)
        let daysToThreshold = ageAtThreshold.map { max(0, $0 - latest.ageDays) }
        let projectedDate: Date? = {
            guard let anchorDate, let ageAtThreshold else { return nil }
            return anchorDate.addingTimeInterval(ageAtThreshold * 86_400.0)
        }()

        return WearProjection(
            modelName: best.name,
            sampleCount: points.count,
            currentHealthPercent: latest.healthPercent,
            wearPercent: 100 - latest.healthPercent,
            ratePerDay: rate,
            threshold: threshold,
            projectedDateToThreshold: projectedDate,
            daysToThreshold: daysToThreshold,
            r2: points.count > 1 ? best.r2 : nil,
            confidence: Self.confidence(count: points.count,
                                        spanDays: (points.last?.ageDays ?? 0) - (points.first?.ageDays ?? 0),
                                        r2: best.r2)
        )
    }

    static func confidence(count: Int, spanDays: Double, r2: Double) -> WearProjection.Confidence {
        if count <= 1 || spanDays < 7 { return .low }
        if count >= 4 && spanDays >= 30 && r2 >= 0.8 { return .high }
        return .medium
    }
}
