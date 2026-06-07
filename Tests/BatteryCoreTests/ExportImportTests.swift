import XCTest
@testable import BatteryCore

final class ExportImportTests: XCTestCase {
    func makeDoc() -> ExportDocument {
        let id = DeviceIdentity(serial: "A1", model: "SM-S931B", codename: "pa1q", manufacturer: "samsung")
        let profile = DeviceProfile(identity: id, firstUseDate: date(2025, 8, 12))
        let samples = [
            BatterySample(deviceSerial: "A1", timestamp: date(2026, 1, 1), levelPercent: 80, healthPercent: 97),
            BatterySample(deviceSerial: "A1", timestamp: date(2026, 6, 1), levelPercent: 66, healthPercent: 96),
        ]
        return ExportDocument(devices: [profile], samples: samples, exportedAt: date(2026, 6, 8))
    }

    func testJSONRoundTrip() throws {
        let doc = makeDoc()
        let data = try doc.jsonData()
        let decoded = try ExportDocument.decode(data)
        XCTAssertEqual(decoded, doc)
        XCTAssertEqual(decoded.schemaVersion, ExportDocument.currentSchemaVersion)
    }

    func testImportMergesAndDedups() async throws {
        let repo = InMemorySampleRepository()
        // First import: everything is new.
        let r1 = try await makeDoc().merge(into: repo)
        XCTAssertEqual(r1.devicesAdded, 1)
        XCTAssertEqual(r1.samplesAdded, 2)
        XCTAssertEqual(r1.samplesSkipped, 0)

        // Re-import same doc: device updated (not re-added), all samples are duplicates.
        let r2 = try await makeDoc().merge(into: repo)
        XCTAssertEqual(r2.devicesAdded, 0)
        XCTAssertEqual(r2.samplesAdded, 0)
        XCTAssertEqual(r2.samplesSkipped, 2)

        let stored = await repo.samples(forDevice: "A1")
        XCTAssertEqual(stored.count, 2)
    }

    func testRejectsNewerSchema() throws {
        var doc = makeDoc()
        doc.schemaVersion = ExportDocument.currentSchemaVersion + 1
        let data = try doc.jsonData()
        XCTAssertThrowsError(try ExportDocument.decode(data)) { error in
            XCTAssertEqual(error as? ExportDocument.ImportError,
                           .unsupportedSchemaVersion(doc.schemaVersion))
        }
    }

    func testSnapshotReflectsRepository() async throws {
        let repo = InMemorySampleRepository()
        _ = try await makeDoc().merge(into: repo)
        let snap = try await ExportDocument.snapshot(of: repo, at: date(2026, 6, 8))
        XCTAssertEqual(snap.devices.count, 1)
        XCTAssertEqual(snap.samples.count, 2)
    }
}
