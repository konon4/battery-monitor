import Foundation

/// Projection of battery wear against **charge cycles** rather than calendar time.
///
/// Complements ``WearProjection``: that answers *"when will this battery reach the
/// threshold"*, this answers *"how many charge cycles are left in it"* — the figure phone
/// makers publish ("80 % capacity after 800 cycles") and the one a customer recognises.
/// Both matter because a phone can be old in years but young in cycles, and vice versa.
public struct CycleProjection: Sendable, Hashable {
    /// How the projection was derived.
    public enum Basis: String, Sendable {
        case fitted              // ≥2 readings spanning enough cycles → per-device rate fitted
        case anchoredToReading   // one usable reading → rated curve scaled through it
        case ratedCurveOnly      // no measurable fade yet → the chemistry's rated curve
    }

    public let chemistry: BatteryChemistry
    public let cyclesNow: Int
    public let currentHealthPercent: Double
    public let threshold: Double                 // end-of-life health %, e.g. 80

    public let cyclesAtThreshold: Int            // total cycles when the threshold is reached
    public let cyclesRemaining: Int
    public let cyclesAtThresholdEarly: Int       // heavy-use bound (fewer cycles)
    public let cyclesAtThresholdLate: Int        // gentle-use bound (more cycles)

    public let lossPer100Cycles: Double          // local fade slope, % of design per 100 cycles
    public let cyclesPerDay: Double?             // observed usage rate, when derivable
    public let projectedDate: Date?              // when the remaining cycles are used up
    public let ratedCycles: Int                  // manufacturer-class rating, for context

    public let basis: Basis
    public let confidence: WearProjection.Confidence
    public let sampleCount: Int
    /// True when the cycle count came from the user rather than the device.
    public let cyclesAreManual: Bool

    /// Share of the projected cycle life already consumed (0…1).
    public var lifeUsedFraction: Double {
        guard cyclesAtThreshold > 0 else { return 0 }
        return min(1, Double(cyclesNow) / Double(cyclesAtThreshold))
    }
}

/// Chemistry-aware projector of remaining charge cycles.
///
/// Model: `loss(n) = β·n^w` where `n` is equivalent full cycles and `w` is the chemistry's
/// ``BatteryChemistry/cycleExponent``. β is fitted from the device's own readings when
/// there are enough of them, otherwise the rated curve is scaled through the latest
/// reading; either way β is clamped to the chemistry's plausible band so one early
/// measurement cannot extrapolate to an absurd cycle life.
public struct CycleEstimator: Sendable {
    /// Loss fraction at which published cycle ratings are defined (80 % of original).
    static let ratedEolLoss = 0.20

    public let threshold: Double   // health %, e.g. 80
    public init(threshold: Double = 80) { self.threshold = threshold }

    /// A cycle count supplied by the user, for devices that never expose one over ADB
    /// (Xiaomi/MIUI, most non-Samsung Android) — read off the phone's own engineering menu.
    public struct ManualCycles: Sendable, Hashable {
        public let count: Int
        public let recordedAt: Date
        public init(count: Int, recordedAt: Date) {
            self.count = count
            self.recordedAt = recordedAt
        }
    }

    public func project(samples: [BatterySample],
                        chemistry: BatteryChemistry,
                        manualCycles: ManualCycles? = nil,
                        firstUseDate: Date? = nil,
                        now: Date) -> CycleProjection? {
        let w = chemistry.cycleExponent
        let lossEol = 1 - threshold / 100

        // Readings that carry both a cycle count and a health figure, oldest first.
        let measured = samples.compactMap { s -> (n: Double, soh: Double, t: Date)? in
            guard let c = s.cycleCount, c > 0, let h = s.healthPercent else { return nil }
            return (Double(c), h / 100, s.timestamp)
        }.sorted { $0.t < $1.t }

        // Health to anchor on: the latest reading that has one.
        guard let latestHealth = samples.compactMap({ $0.healthPercent }).last else { return nil }
        let sohNow = latestHealth / 100

        let cyclesNow: Double
        let isManual: Bool
        if let latest = measured.last {
            cyclesNow = latest.n
            isManual = false
        } else if let manual = manualCycles, manual.count > 0 {
            cyclesNow = Double(manual.count)
            isManual = true
        } else {
            return nil   // no cycle information at all
        }

        // β prior: the rated curve, expressed at the standard 80 % definition so a custom
        // threshold still projects consistently.
        let prior = Self.ratedEolLoss / pow(Double(chemistry.ratedCycles), w)
        let betaSlow = Self.ratedEolLoss / pow(Double(chemistry.ratedCyclesRange.upperBound), w)
        let betaFast = Self.ratedEolLoss / pow(Double(chemistry.ratedCyclesRange.lowerBound), w)

        var beta: Double
        var basis: CycleProjection.Basis
        var confidence: WearProjection.Confidence

        let cycleSpan = (measured.map(\.n).max() ?? 0) - (measured.map(\.n).min() ?? 0)
        let sohSpan = ((measured.map(\.soh).max() ?? 0) - (measured.map(\.soh).min() ?? 0)) * 100

        if measured.count >= 2, cycleSpan >= 25, sohSpan >= 1.0 {
            // Least squares through the origin, then shrink toward the rated prior.
            let num = measured.reduce(0.0) { $0 + pow($1.n, w) * (1 - $1.soh) }
            let den = measured.reduce(0.0) { $0 + pow($1.n, 2 * w) }
            let fit = den > 0 ? num / den : prior
            let shrink = min(1.0, Double(measured.count - 1) / 3.0)
            beta = shrink * fit + (1 - shrink) * prior
            basis = .fitted
            confidence = (measured.count >= 4 && cycleSpan >= 60) ? .high : .medium
        } else if 1 - sohNow > 0.005, cyclesNow >= 25 {
            // Scale the rated curve through the one reading we trust.
            beta = (1 - sohNow) / pow(cyclesNow, w)
            basis = .anchoredToReading
            confidence = .low
        } else {
            // Too new to have measurable fade — quote the rated curve.
            beta = prior
            basis = .ratedCurveOnly
            confidence = .low
        }
        beta = min(max(beta, betaSlow), betaFast)

        func cyclesAt(_ b: Double) -> Double { pow(lossEol / b, 1 / w) }
        let eol = cyclesAt(beta)
        let remaining = max(0, eol - cyclesNow)

        // Local fade slope at the current cycle count, per 100 cycles.
        let slope = beta * w * pow(max(cyclesNow, 1), w - 1) * 100 * 100

        // Usage rate: prefer what we have actually observed, else spread the count over the
        // battery's life so far.
        var perDay: Double?
        if let first = measured.first, let last = measured.last {
            let days = last.t.timeIntervalSince(first.t) / 86_400
            let dn = last.n - first.n
            if days >= 14, dn >= 5 { perDay = dn / days }
        }
        if perDay == nil, let firstUse = firstUseDate {
            let anchor = isManual ? (manualCycles?.recordedAt ?? now) : (measured.last?.t ?? now)
            let days = anchor.timeIntervalSince(firstUse) / 86_400
            if days >= 7 { perDay = cyclesNow / days }
        }
        let projectedDate = perDay.flatMap { rate -> Date? in
            guard rate > 0.001 else { return nil }
            return now.addingTimeInterval(remaining / rate * 86_400)
        }

        return CycleProjection(
            chemistry: chemistry,
            cyclesNow: Int(cyclesNow),
            currentHealthPercent: sohNow * 100,
            threshold: threshold,
            cyclesAtThreshold: Int(eol.rounded()),
            cyclesRemaining: Int(remaining.rounded()),
            cyclesAtThresholdEarly: Int(cyclesAt(betaFast).rounded()),
            cyclesAtThresholdLate: Int(cyclesAt(betaSlow).rounded()),
            lossPer100Cycles: min(slope, 25),
            cyclesPerDay: perDay,
            projectedDate: projectedDate,
            ratedCycles: chemistry.ratedCycles,
            basis: basis,
            confidence: confidence,
            sampleCount: measured.isEmpty ? 1 : measured.count,
            cyclesAreManual: isManual
        )
    }
}
