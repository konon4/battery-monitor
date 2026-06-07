import XCTest
@testable import BatteryCore

final class WearEstimatorTests: XCTestCase {
    let firstUse = date(2025, 8, 12)

    func testSingleMeasurementLinearProjection() {
        // One point: 96% health at 300 days → 4% loss / 300d = 0.0133%/day.
        // 20% total loss to reach 80% → age 1500d, i.e. 1200 more days.
        let p = [WearPoint(ageDays: 300, healthPercent: 96)]
        let est = WearEstimator()
        let proj = est.project(points: p, anchorDate: firstUse)!
        XCTAssertEqual(proj.currentHealthPercent, 96)
        XCTAssertEqual(proj.wearPercent, 4, accuracy: 1e-9)
        XCTAssertEqual(proj.ratePerDay, 4.0 / 300.0, accuracy: 1e-9)
        XCTAssertEqual(proj.daysToThreshold!, 1200, accuracy: 1e-6)
        XCTAssertEqual(proj.confidence, .low)
        assertDate(proj.projectedDateToThreshold,
                   firstUse.addingTimeInterval(1500 * 86_400), accuracy: 1)
    }

    func testLinearTrendRecoveredFromManyPoints() {
        // Perfectly linear: health = 100 - 0.05*t. Should fit and project 80% at t=400.
        let pts = stride(from: 30.0, through: 360.0, by: 30.0).map {
            WearPoint(ageDays: $0, healthPercent: 100 - 0.05 * $0)
        }
        let proj = WearEstimator().project(points: pts, anchorDate: firstUse)!
        XCTAssertEqual(proj.ratePerDay, 0.05, accuracy: 1e-6)
        let ageAt80 = (proj.daysToThreshold! + pts.last!.ageDays)
        XCTAssertEqual(ageAt80, 400, accuracy: 1e-3)
        XCTAssertGreaterThan(proj.r2!, 0.99)
        XCTAssertEqual(proj.confidence, .high)
    }

    func testSqrtAgingPreferredForSqrtData() {
        // health = 100 - 1.2*sqrt(t): the √t model should win on R².
        let pts = stride(from: 10.0, through: 360.0, by: 20.0).map {
            WearPoint(ageDays: $0, healthPercent: 100 - 1.2 * ($0).squareRoot())
        }
        let proj = WearEstimator().project(points: pts, anchorDate: firstUse)!
        XCTAssertEqual(proj.modelName, "√t calendar aging")
        XCTAssertGreaterThan(proj.r2!, 0.999)
    }

    func testEmptyPointsYieldNoProjection() {
        XCTAssertNil(WearEstimator().project(points: [], anchorDate: firstUse))
    }

    func testConfidenceGrowsWithData() {
        XCTAssertEqual(WearEstimator.confidence(count: 1, spanDays: 0, r2: 1), .low)
        XCTAssertEqual(WearEstimator.confidence(count: 2, spanDays: 20, r2: 0.5), .medium)
        XCTAssertEqual(WearEstimator.confidence(count: 5, spanDays: 90, r2: 0.95), .high)
    }

    func testPointsBuilderAgesFromFirstUse() {
        let samples = [
            BatterySample(deviceSerial: "a", timestamp: firstUse.addingTimeInterval(100 * 86_400),
                          levelPercent: 80, healthPercent: 98),
            BatterySample(deviceSerial: "a", timestamp: firstUse.addingTimeInterval(-10),
                          levelPercent: 50, healthPercent: 100), // before first-use → dropped
            BatterySample(deviceSerial: "a", timestamp: firstUse.addingTimeInterval(200 * 86_400),
                          levelPercent: 60, healthPercent: nil), // no health → dropped
        ]
        let pts = WearEstimator.points(from: samples, firstUseDate: firstUse)
        XCTAssertEqual(pts.count, 1)
        XCTAssertEqual(pts[0].ageDays, 100, accuracy: 1e-6)
        XCTAssertEqual(pts[0].healthPercent, 98)
    }
}

private extension XCTestCase {
    func assertDate(_ a: Date?, _ b: Date, accuracy: TimeInterval,
                    file: StaticString = #filePath, line: UInt = #line) {
        guard let a else { return XCTFail("nil date", file: file, line: line) }
        XCTAssertEqual(a.timeIntervalSince1970, b.timeIntervalSince1970, accuracy: accuracy,
                       file: file, line: line)
    }
}
