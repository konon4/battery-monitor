import XCTest
@testable import BatteryCore

final class WearEstimatorTests: XCTestCase {
    let firstUse = date(2025, 8, 12)
    let est = WearEstimator(threshold: 80)

    private func sample(_ ts: Date, _ health: Double) -> BatterySample {
        BatterySample(deviceSerial: "d", timestamp: ts, levelPercent: 50, healthPercent: health)
    }

    // MARK: The bug this replaces — sparse/close readings must NOT extrapolate to "dead soon".

    func testTwoCloseReadingsDoNotProduceAbsurdProjection() {
        // 90% now, no first-use date (Xiaomi case). Previously this gave ~0.6%/day → dead in 17 days.
        let now = date(2026, 6, 10)
        let samples = [sample(date(2026, 5, 25), 91), sample(now, 90)]
        let p = est.project(samples: samples, firstUseDate: nil, chemistry: .graphite, now: now)!
        XCTAssertEqual(p.basis, .typicalCurveNoDate)
        XCTAssertEqual(p.confidence, .low)
        // Must be years, not days, away.
        XCTAssertGreaterThan(p.daysToThreshold!, 365)
        // Local rate is sane (not hundreds of %/yr).
        XCTAssertLessThan(p.ratePerYearPercent, 25)
        XCTAssertGreaterThan(p.ratePerYearPercent, 0)
    }

    func testSingleReadingWithAgeAnchorsTypicalCurve() {
        // S25-like: 96% at ~10 months, one reading.
        let now = firstUse.addingTimeInterval(300 * 86_400)
        let p = est.project(samples: [sample(now, 96)], firstUseDate: firstUse, chemistry: .graphite, now: now)!
        XCTAssertEqual(p.basis, .anchoredToReading)
        XCTAssertEqual(p.currentHealthPercent, 96, accuracy: 1e-6)
        // Curve passes through the reading: ~96% at the reading's age.
        XCTAssertEqual(p.healthPercent(at: now)!, 96, accuracy: 0.5)
        // Decelerating √t-ish curve → years to 80%, well beyond 1 year.
        XCTAssertGreaterThan(p.daysToThreshold!, 365)
    }

    // MARK: Fitting with enough well-separated data.

    func testFitsRateFromManyReadings() {
        // Synthetic graphite curve SOH = 1 - 0.05*t^0.75 sampled monthly for a year.
        let z = 0.75, alpha = 0.05
        let samples = stride(from: 30.0, through: 360.0, by: 30.0).map { day -> BatterySample in
            let t = day / 365.25
            let soh = (1 - alpha * pow(t, z)) * 100
            return sample(firstUse.addingTimeInterval(day * 86_400), soh)
        }
        let now = firstUse.addingTimeInterval(360 * 86_400)
        let p = est.project(samples: samples, firstUseDate: firstUse, chemistry: .graphite, now: now)!
        XCTAssertEqual(p.basis, .fitted)
        XCTAssertEqual(p.confidence, .high)
        // Recovered α is close to the true 0.05 (shrunk slightly toward the 0.045 prior).
        XCTAssertEqual(p.curveAlpha, 0.05, accuracy: 0.01)
    }

    // MARK: Chemistry differences.

    func testChemistryChangesProjection() {
        let now = firstUse.addingTimeInterval(300 * 86_400)
        let s = [sample(now, 90)]
        let lfp = est.project(samples: s, firstUseDate: firstUse, chemistry: .lfp, now: now)!
        let si = est.project(samples: s, firstUseDate: firstUse, chemistry: .siliconCarbon, now: now)!
        XCTAssertEqual(lfp.chemistry, .lfp)
        XCTAssertEqual(si.chemistry, .siliconCarbon)
        // Same reading, different curve shape → different time-to-threshold.
        XCTAssertNotEqual(lfp.daysToThreshold!, si.daysToThreshold!, accuracy: 1)
    }

    func testRateClampedAndBandOrdered() {
        let now = firstUse.addingTimeInterval(300 * 86_400)
        let p = est.project(samples: [sample(now, 60)], firstUseDate: firstUse, chemistry: .graphite, now: now)!
        XCTAssertLessThanOrEqual(p.ratePerYearPercent, 25)
        // Early (fast use) bound is on/before the late (slow use) bound.
        XCTAssertLessThanOrEqual(p.projectedDateEarly!, p.projectedDateLate!)
    }

    func testNoHealthReadingsYieldsNil() {
        let s = [BatterySample(deviceSerial: "d", timestamp: date(2026, 6, 1), levelPercent: 50)]
        XCTAssertNil(est.project(samples: s, firstUseDate: firstUse, chemistry: .graphite, now: date(2026, 6, 1)))
    }
}
