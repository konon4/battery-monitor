import XCTest
@testable import BatteryCore

final class ADBParsingTests: XCTestCase {
    func testParsesDeviceList() {
        let out = """
        List of devices attached
        RFCY50QFS2B            device usb:0-1 product:pa1qxxx model:SM_S931B device:pa1q transport_id:1
        EMULATOR30X1Y2         unauthorized transport_id:2
        ZX1G42abcd             offline
        * daemon line should be ignored *
        """
        let devices = ADBClient.parseDevices(out)
        XCTAssertEqual(devices.count, 3)
        XCTAssertEqual(devices[0].serial, "RFCY50QFS2B")
        XCTAssertEqual(devices[0].state, .device)
        XCTAssertEqual(devices[0].model, "SM-S931B")   // underscores normalised
        XCTAssertTrue(devices[0].isReady)
        XCTAssertEqual(devices[1].state, .unauthorized)
        XCTAssertEqual(devices[2].state, .offline)
    }

    func testEmptyListWhenNoDevices() {
        XCTAssertTrue(ADBClient.parseDevices("List of devices attached\n\n").isEmpty)
    }

    func testMapErrorUnauthorized() {
        XCTAssertThrowsError(try ADBClient.mapError(
            stderr: "error: device unauthorized.\nThis adb server's $ADB_VENDOR_KEYS...",
            args: ["-s", "RFCY50QFS2B", "shell", "dumpsys battery"])) {
            XCTAssertEqual($0 as? ADBError, .deviceUnauthorized(serial: "RFCY50QFS2B"))
        }
    }

    func testMapErrorOffline() {
        XCTAssertThrowsError(try ADBClient.mapError(stderr: "error: device offline",
                                                    args: ["-s", "X", "shell", "x"])) {
            XCTAssertEqual($0 as? ADBError, .deviceOffline(serial: "X"))
        }
    }

    func testDesignCapacityCatalog() {
        XCTAssertEqual(DesignCapacityCatalog.capacity(forModel: "SM-S931B"), 4000)
        XCTAssertEqual(DesignCapacityCatalog.capacity(forModel: "SM-S938U"), 5000)
        XCTAssertEqual(DesignCapacityCatalog.capacity(forModel: "M2012K11AG"), 4520)
        XCTAssertNil(DesignCapacityCatalog.capacity(forModel: "Pixel 8"))
    }
}
