import XCTest
@testable import BatteryCore

/// Anchored on the two physically measured devices in the project:
/// • Galaxy S25 (SM-S931B) — 264 cycles at 96 % health, first used 2025-08-12.
///   Cycles read over ADB from Samsung's accumulated-discharge counter.
/// • Poco F3 (M2012K11AG) — 407 cycles at ~91 % health, read by hand from the phone's
///   `*#*#6485#*#*` menu (MB_07) because MIUI exposes no cycle count over ADB.
final class CycleEstimatorTests: XCTestCase {
    let now = date(2026, 8, 30)

    private func sample(cycles: Int?, health: Double?, at when: Date) -> BatterySample {
        BatterySample(deviceSerial: "D", timestamp: when, levelPercent: 90,
                      healthPercent: health, cycleCount: cycles)
    }

    // MARK: Device-read cycles (Samsung)

    func testProjectsRemainingCyclesFromSingleReading() throws {
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: [sample(cycles: 264, health: 96, at: now)],
            chemistry: .graphite, firstUseDate: date(2025, 8, 12), now: now))

        XCTAssertEqual(p.cyclesNow, 264)
        XCTAssertEqual(p.basis, .anchoredToReading)
        XCTAssertEqual(p.confidence, .low)
        XCTAssertFalse(p.cyclesAreManual)
        // 4 % lost over 264 cycles → 20 % at ~1320 cycles.
        XCTAssertEqual(p.cyclesAtThreshold, 1320, accuracy: 5)
        XCTAssertEqual(p.cyclesRemaining, 1056, accuracy: 5)
        XCTAssertEqual(p.lossPer100Cycles, 1.52, accuracy: 0.05)
        // 264 cycles over 383 days in service.
        XCTAssertEqual(try XCTUnwrap(p.cyclesPerDay), 0.69, accuracy: 0.02)
        XCTAssertNotNil(p.projectedDate)
        XCTAssertEqual(p.lifeUsedFraction, 0.2, accuracy: 0.02)
    }

    /// The uncertainty band must straddle the estimate and stay inside the rated band.
    func testBoundsBracketTheEstimate() throws {
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: [sample(cycles: 264, health: 96, at: now)],
            chemistry: .graphite, firstUseDate: date(2025, 8, 12), now: now))
        XCTAssertEqual(p.cyclesAtThresholdEarly, BatteryChemistry.graphite.ratedCyclesRange.lowerBound)
        XCTAssertEqual(p.cyclesAtThresholdLate, BatteryChemistry.graphite.ratedCyclesRange.upperBound)
        XCTAssertLessThan(p.cyclesAtThresholdEarly, p.cyclesAtThreshold)
        XCTAssertGreaterThan(p.cyclesAtThresholdLate, p.cyclesAtThreshold)
    }

    // MARK: Manually entered cycles (Xiaomi)

    func testUsesManualCycleCountWhenDeviceReportsNone() throws {
        // Poco F3: MIUI reports no cycle count, so the shop enters what MB_07 showed.
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: [sample(cycles: nil, health: 91.2, at: now)],
            chemistry: .graphite,
            manualCycles: .init(count: 407, recordedAt: now),
            firstUseDate: nil, now: now))

        XCTAssertTrue(p.cyclesAreManual)
        XCTAssertEqual(p.cyclesNow, 407)
        // 8.8 % lost over 407 cycles → 20 % at ~925 cycles.
        XCTAssertEqual(p.cyclesAtThreshold, 925, accuracy: 10)
        XCTAssertEqual(p.cyclesRemaining, 518, accuracy: 10)
        XCTAssertEqual(p.lossPer100Cycles, 2.16, accuracy: 0.05)
        // No first-use date and a single reading → no usage rate, so no calendar date.
        XCTAssertNil(p.cyclesPerDay)
        XCTAssertNil(p.projectedDate)
    }

    func testDeviceReportedCyclesWinOverManualEntry() throws {
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: [sample(cycles: 264, health: 96, at: now)],
            chemistry: .graphite,
            manualCycles: .init(count: 999, recordedAt: now),
            firstUseDate: nil, now: now))
        XCTAssertEqual(p.cyclesNow, 264)
        XCTAssertFalse(p.cyclesAreManual)
    }

    // MARK: Guards

    func testFitsRateAcrossReadingsAndDerivesUsageRate() throws {
        let start = date(2026, 1, 1)
        let samples = (0..<4).map { i in
            sample(cycles: 200 + i * 60, health: 97 - Double(i) * 1.2,
                   at: start.addingTimeInterval(Double(i) * 60 * 86_400))
        }
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: samples, chemistry: .graphite, firstUseDate: nil, now: now))
        XCTAssertEqual(p.basis, .fitted)
        XCTAssertEqual(p.confidence, .high)
        XCTAssertEqual(p.sampleCount, 4)
        // 60 cycles per 60 days of history.
        XCTAssertEqual(try XCTUnwrap(p.cyclesPerDay), 1.0, accuracy: 0.05)
    }

    /// A nearly-new battery cannot extrapolate to an absurd cycle life.
    func testBarelyUsedBatteryFallsBackToRatedCurve() throws {
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: [sample(cycles: 3, health: 100, at: now)],
            chemistry: .graphite, firstUseDate: date(2026, 8, 20), now: now))
        XCTAssertEqual(p.basis, .ratedCurveOnly)
        XCTAssertEqual(p.cyclesAtThreshold, BatteryChemistry.graphite.ratedCycles)
    }

    func testClampsImplausiblyGoodReadingToRatedBand() throws {
        // 0.5 % loss at 400 cycles would imply ~16 000 cycles — clamped to the band.
        let p = try XCTUnwrap(CycleEstimator().project(
            samples: [sample(cycles: 400, health: 99.5, at: now)],
            chemistry: .graphite, firstUseDate: nil, now: now))
        XCTAssertEqual(p.cyclesAtThreshold, BatteryChemistry.graphite.ratedCyclesRange.upperBound)
    }

    func testChemistryChangesCycleLife() throws {
        let s = [sample(cycles: 300, health: 95, at: now)]
        let graphite = try XCTUnwrap(CycleEstimator().project(samples: s, chemistry: .graphite, now: now))
        let lfp = try XCTUnwrap(CycleEstimator().project(samples: s, chemistry: .lfp, now: now))
        XCTAssertGreaterThan(lfp.cyclesAtThreshold, graphite.cyclesAtThreshold)
    }

    func testReturnsNilWithoutAnyCycleInformation() {
        XCTAssertNil(CycleEstimator().project(
            samples: [sample(cycles: nil, health: 95, at: now)],
            chemistry: .graphite, now: now))
    }

    func testReturnsNilWithoutHealthReading() {
        XCTAssertNil(CycleEstimator().project(
            samples: [sample(cycles: 264, health: nil, at: now)],
            chemistry: .graphite, now: now))
    }

    /// A lower end-of-life threshold must leave more usable cycles.
    func testLowerThresholdLeavesMoreCycles() throws {
        let s = [sample(cycles: 264, health: 96, at: now)]
        let at80 = try XCTUnwrap(CycleEstimator(threshold: 80).project(samples: s, chemistry: .graphite, now: now))
        let at70 = try XCTUnwrap(CycleEstimator(threshold: 70).project(samples: s, chemistry: .graphite, now: now))
        XCTAssertGreaterThan(at70.cyclesRemaining, at80.cyclesRemaining)
    }
}

private func XCTAssertEqual(_ a: Int, _ b: Int, accuracy: Int,
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertLessThanOrEqual(abs(a - b), accuracy,
                             "\(a) is not within \(accuracy) of \(b)", file: file, line: line)
}
