import Foundation

/// Projection of battery wear forward in time, with an uncertainty band.
public struct WearProjection: Sendable, Hashable {
    /// How the projection was derived.
    public enum Basis: String, Sendable {
        case fitted              // ≥3 well-separated readings → individual rate fitted
        case anchoredToReading   // few readings → chemistry curve scaled through the latest one
        case typicalCurveNoDate  // no first-use date → device placed on the typical curve
    }
    public enum Confidence: String, Sendable { case low, medium, high }

    public let chemistry: BatteryChemistry
    public let currentHealthPercent: Double
    public let wearPercent: Double
    public let ratePerYearPercent: Double          // local fade rate at the current age
    public let threshold: Double                    // end-of-life health %, e.g. 80

    public let daysToThreshold: Double?             // typical
    public let projectedDate: Date?                 // typical
    public let projectedDateEarly: Date?            // fast-use bound (sooner)
    public let projectedDateLate: Date?             // slow-use bound (later)

    public let basis: Basis
    public let confidence: Confidence
    public let sampleCount: Int

    // Curve params for charting: SOH(t) = 1 − α·((date−anchor)/year)^z
    public let curveAnchor: Date?
    public let curveAlpha: Double
    public let curveZ: Double

    /// Modelled health % at a future/elapsed date along the fitted curve.
    public func healthPercent(at date: Date) -> Double? {
        guard let anchor = curveAnchor else { return nil }
        let t = date.timeIntervalSince(anchor) / WearEstimator.year
        guard t >= 0 else { return nil }
        return max(0, 100 * (1 - curveAlpha * pow(t, curveZ)))
    }
}

/// Chemistry-aware capacity-fade projector.
///
/// Model: `SOH(t) = 1 − α·t^z`, with z and the α prior set per ``BatteryChemistry``.
/// Crucially it projects against **battery age** (from first-use date), never against the
/// gap between sample timestamps — and it constrains the curve shape so sparse, closely
/// spaced readings can't produce absurd "dead in weeks" extrapolations. With few readings
/// it scales the chemistry's typical curve through the latest point and shrinks any fitted
/// rate toward the population prior (empirical-Bayes style).
public struct WearEstimator: Sendable {
    public static let year: TimeInterval = 365.25 * 86_400

    public let threshold: Double   // health %, e.g. 80
    public init(threshold: Double = 80) { self.threshold = threshold }

    public func project(samples: [BatterySample],
                        firstUseDate: Date?,
                        chemistry: BatteryChemistry,
                        now: Date) -> WearProjection? {
        let health = samples.compactMap { s -> (t: Date, soh: Double)? in
            guard let h = s.healthPercent else { return nil }
            return (s.timestamp, h / 100)
        }.sorted { $0.t < $1.t }
        guard let latest = health.last else { return nil }

        let z = chemistry.exponent
        let prior = chemistry.alphaPrior
        let range = chemistry.alphaRange
        let lossEol = 1 - threshold / 100
        let sohNow = latest.soh

        var alpha: Double
        var ageNow: Double                 // years
        var anchor: Date
        var basis: WearProjection.Basis
        var confidence: WearProjection.Confidence
        let n = health.count

        if let firstUse = firstUseDate {
            anchor = firstUse
            ageNow = max(0.02, latest.t.timeIntervalSince(firstUse) / Self.year)
            let pts = health.map { (age: $0.t.timeIntervalSince(firstUse) / Self.year, soh: $0.soh) }
                .filter { $0.age > 0.02 }
            let ageSpanDays = ((pts.map(\.age).max() ?? 0) - (pts.map(\.age).min() ?? 0)) * 365.25
            let sohSpan = ((pts.map(\.soh).max() ?? 0) - (pts.map(\.soh).min() ?? 0)) * 100

            if pts.count >= 3, ageSpanDays >= 30, sohSpan >= 1.5 {
                // Fit α with z fixed, then shrink toward the prior.
                let num = pts.reduce(0.0) { $0 + pow($1.age, z) * (1 - $1.soh) }
                let den = pts.reduce(0.0) { $0 + pow($1.age, 2 * z) }
                let fit = den > 0 ? num / den : prior
                let w = min(1.0, Double(pts.count - 2) / 3.0)
                alpha = w * fit + (1 - w) * prior
                basis = .fitted
                confidence = (pts.count >= 4 && ageSpanDays >= 60) ? .high : .medium
            } else {
                // Scale the chemistry's typical curve through the latest reading.
                alpha = (1 - sohNow) / pow(ageNow, z)
                basis = .anchoredToReading
                confidence = .low
            }
        } else {
            // No real age: place the device on the chemistry's typical curve.
            alpha = prior
            ageNow = pow(max(0, 1 - sohNow) / prior, 1 / z)
            anchor = now.addingTimeInterval(-ageNow * Self.year)
            basis = .typicalCurveNoDate
            confidence = .low
        }
        alpha = min(max(alpha, range.lowerBound), range.upperBound)

        // Date at which a given α reaches the threshold (anchored consistently per branch).
        func eolDate(_ a: Double) -> Date {
            let ageEol = pow(lossEol / a, 1 / z)
            if firstUseDate != nil {
                return anchor.addingTimeInterval(ageEol * Self.year)
            } else {
                let ageAt = pow(max(0, 1 - sohNow) / a, 1 / z)        // implied "now" for this α
                let days = max(0, ageEol - ageAt)
                return now.addingTimeInterval(days * Self.year)
            }
        }
        let ageEol = pow(lossEol / alpha, 1 / z)
        let daysTo = max(0, ageEol - ageNow) * 365.25
        var rate = alpha * z * pow(ageNow, z - 1) * 100   // %/yr local slope
        rate = min(rate, 25)

        return WearProjection(
            chemistry: chemistry,
            currentHealthPercent: sohNow * 100,
            wearPercent: (1 - sohNow) * 100,
            ratePerYearPercent: rate,
            threshold: threshold,
            daysToThreshold: daysTo,
            projectedDate: eolDate(alpha),
            projectedDateEarly: eolDate(range.upperBound),
            projectedDateLate: eolDate(range.lowerBound),
            basis: basis,
            confidence: confidence,
            sampleCount: n,
            curveAnchor: anchor,
            curveAlpha: alpha,
            curveZ: z
        )
    }
}
