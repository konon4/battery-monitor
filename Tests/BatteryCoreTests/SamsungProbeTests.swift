import XCTest
@testable import BatteryCore

final class SamsungProbeTests: XCTestCase {
    let s25 = DeviceIdentity(serial: "RFCY50QFS2B", model: "SM-S931B",
                             codename: "pa1q", manufacturer: "samsung")

    func testParsesRealS25Dump() throws {
        let dump = try Fixture.text("s25_dumpsys", ext: "txt")
        let now = date(2026, 6, 8)
        let result = SamsungProbe.parse(dump, identity: s25, now: now)
        let s = result.sample

        XCTAssertEqual(s.levelPercent, 66)
        XCTAssertEqual(s.healthPercent, 96)                 // ASOC — the headline metric
        XCTAssertEqual(s.bsoh, 100.0)
        XCTAssertEqual(s.voltage!, 4.114, accuracy: 1e-6)   // 4114 mV
        XCTAssertEqual(s.temperatureC!, 37.7, accuracy: 1e-6) // 377 → 37.7°C
        XCTAssertEqual(s.chargeCounterMAh!, 2719.85, accuracy: 1e-6)
        XCTAssertNil(s.cycleCount)                           // not trusted over ADB on S25

        // estimated full capacity = 96% × 4000 mAh design = 3840
        XCTAssertEqual(s.estimatedFullCapacityMAh!, 3840, accuracy: 1e-6)
        XCTAssertEqual(result.designCapacityMAh, 4000)

        // dates
        XCTAssertEqual(result.firstUseDate, date(2025, 8, 12))
        XCTAssertEqual(result.cellManufactureDate, date(2025, 5, 14))
    }

    func testDoesNotMisparseSimilarKeys() throws {
        // Guards the prefix-anchored scanner: "Max charging voltage: 0" and
        // "Capacity level: -1" must not hijack voltage/level.
        let dump = try Fixture.text("s25_dumpsys", ext: "txt")
        let s = SamsungProbe.parse(dump, identity: s25, now: date(2026, 6, 8)).sample
        XCTAssertEqual(s.levelPercent, 66)          // not -1
        XCTAssertEqual(s.voltage!, 4.114, accuracy: 1e-6) // not 0
    }

    func testRoutesThroughRegistryWithFakeRunner() async throws {
        let dump = try Fixture.text("s25_dumpsys", ext: "txt")
        let runner = FakeShellRunner(responses: ["dumpsys battery": dump])
        let registry = DeviceRegistry.standard
        XCTAssertEqual(registry.probe(for: s25)?.name, "Samsung (One UI)")
        let result = try await registry.read(s25, via: runner, now: date(2026, 6, 8))
        XCTAssertEqual(result.sample.healthPercent, 96)
    }

    func testUnknownVendorFallsBackToGeneric() {
        let pixel = DeviceIdentity(serial: "x", model: "Pixel 8", codename: "shiba", manufacturer: "Google")
        XCTAssertEqual(DeviceRegistry.standard.probe(for: pixel)?.name, "Generic Android (AOSP)")
    }
}
