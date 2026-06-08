import XCTest
@testable import BatteryCore

final class XiaomiProbeTests: XCTestCase {
    let pocoF3 = DeviceIdentity(serial: "ca3c6b60", model: "M2012K11AG",
                               codename: "alioth", manufacturer: "Xiaomi")

    func testParsesLearnedCapacityFromBatteryStats() throws {
        let stats = try Fixture.text("poco_f3_batterystats", ext: "txt")
        XCTAssertEqual(BatteryStatsParser.learnedCapacityMAh(stats), 4132)
        XCTAssertEqual(BatteryStatsParser.estimatedCapacityMAh(stats), 3636)
    }

    func testXiaomiProbeComputesHealthFromLearnedVsDesign() async throws {
        let battery = try Fixture.text("poco_f3_dumpsys", ext: "txt")
        let stats = try Fixture.text("poco_f3_batterystats", ext: "txt")
        let runner = FakeShellRunner(responses: [
            "dumpsys batterystats": stats,   // check the more specific command first
            "dumpsys battery": battery,
        ])
        let result = try await XiaomiProbe().read(pocoF3, via: runner, now: date(2026, 6, 8))
        let s = result.sample

        // learned 4132 mAh of 4520 design → ~91.4% health
        XCTAssertEqual(s.estimatedFullCapacityMAh!, 4132, accuracy: 1e-6)
        XCTAssertEqual(s.healthPercent!, 4132.0 / 4520.0 * 100, accuracy: 1e-6)
        XCTAssertEqual(result.designCapacityMAh, 4520)
        // live fields from dumpsys battery
        XCTAssertEqual(s.levelPercent, 59)
        XCTAssertEqual(s.voltage!, 4.204, accuracy: 1e-6)
        XCTAssertEqual(s.temperatureC!, 31.7, accuracy: 1e-6)
        XCTAssertNil(s.cycleCount)   // not available without root on MIUI
        XCTAssertNil(s.bsoh)
    }

    func testRegistryRoutesXiaomiToXiaomiProbe() {
        XCTAssertEqual(DeviceRegistry.standard.probe(for: pocoF3)?.name, "Xiaomi (MIUI/HyperOS)")
    }

    func testGenericProbeUsesBatteryStatsFallback() async throws {
        // A non-Samsung, non-Xiaomi device with locked sysfs but batterystats available.
        let pixel = DeviceIdentity(serial: "p", model: "Pixel 8", codename: "shiba", manufacturer: "Google")
        let battery = try Fixture.text("poco_f3_dumpsys", ext: "txt")
        let stats = "  Last learned battery capacity: 4500 mAh\n"
        let runner = FakeShellRunner(responses: [
            "dumpsys batterystats": stats,
            "cat /sys": "",           // sysfs locked → empty
            "dumpsys battery": battery,
        ])
        let result = try await GenericAOSPProbe().read(pixel, via: runner, now: date(2026, 6, 8))
        XCTAssertEqual(result.sample.estimatedFullCapacityMAh!, 4500, accuracy: 1e-6)
    }
}
