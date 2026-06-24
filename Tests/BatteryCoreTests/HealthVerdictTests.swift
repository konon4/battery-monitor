import XCTest
@testable import BatteryCore

final class HealthVerdictTests: XCTestCase {
    func testThresholds() {
        XCTAssertEqual(HealthVerdict.from(healthPercent: 100), .good)
        XCTAssertEqual(HealthVerdict.from(healthPercent: 96), .good)
        XCTAssertEqual(HealthVerdict.from(healthPercent: 90), .good)      // boundary → good
        XCTAssertEqual(HealthVerdict.from(healthPercent: 89.9), .fair)
        XCTAssertEqual(HealthVerdict.from(healthPercent: 80), .fair)      // boundary → fair
        XCTAssertEqual(HealthVerdict.from(healthPercent: 79.9), .serviceSoon)
        XCTAssertEqual(HealthVerdict.from(healthPercent: 50), .serviceSoon)
        XCTAssertEqual(HealthVerdict.from(healthPercent: nil), .unknown)
    }

    func testRealDevices() {
        XCTAssertEqual(HealthVerdict.from(healthPercent: 96), .good)        // S25
        XCTAssertEqual(HealthVerdict.from(healthPercent: 91.4), .good)      // Poco F3
    }
}
