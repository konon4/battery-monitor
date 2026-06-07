import Foundation

/// Portable, versioned snapshot of all device profiles and samples.
///
/// This is the JSON written by Export and read by Import. The `schemaVersion` gives us a
/// migration hook for future format changes; the same shape is intended for an Android
/// companion app to emit (later sprint).
public struct ExportDocument: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var devices: [DeviceProfile]
    public var samples: [BatterySample]

    public init(devices: [DeviceProfile], samples: [BatterySample], exportedAt: Date) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.devices = devices
        self.samples = samples
    }

    // MARK: JSON

    public static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    public static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public func jsonData() throws -> Data { try Self.makeEncoder().encode(self) }

    public static func decode(_ data: Data) throws -> ExportDocument {
        let doc = try makeDecoder().decode(ExportDocument.self, from: data)
        try doc.validateAndMigrate()
        return doc
    }

    /// Hook for forward-compatible migrations. Rejects versions newer than we understand.
    func validateAndMigrate() throws {
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw ImportError.unsupportedSchemaVersion(schemaVersion)
        }
        // Future: branch on schemaVersion < current to upgrade in place.
    }

    public enum ImportError: Error, Equatable {
        case unsupportedSchemaVersion(Int)
    }
}

/// Summary of what an import changed.
public struct MergeResult: Sendable, Equatable {
    public var devicesAdded: Int
    public var samplesAdded: Int
    public var samplesSkipped: Int   // duplicates, by (serial, timestamp)

    public init(devicesAdded: Int, samplesAdded: Int, samplesSkipped: Int) {
        self.devicesAdded = devicesAdded
        self.samplesAdded = samplesAdded
        self.samplesSkipped = samplesSkipped
    }
}

public extension ExportDocument {
    /// Merge this document into a repository, deduping samples by (deviceSerial, timestamp).
    func merge(into repo: SampleRepository) async throws -> MergeResult {
        var result = MergeResult(devicesAdded: 0, samplesAdded: 0, samplesSkipped: 0)

        let existingProfiles = Set(try await repo.profiles().map(\.id))
        for device in devices {
            if !existingProfiles.contains(device.id) { result.devicesAdded += 1 }
            try await repo.upsert(profile: device)
        }

        // Build dedup key set from existing samples.
        func key(_ serial: String, _ ts: Date) -> String { "\(serial)|\(ts.timeIntervalSince1970)" }
        var seen = Set((try await repo.allSamples()).map { key($0.deviceSerial, $0.timestamp) })

        for sample in samples {
            let k = key(sample.deviceSerial, sample.timestamp)
            if seen.contains(k) { result.samplesSkipped += 1; continue }
            seen.insert(k)
            try await repo.add(sample: sample)
            result.samplesAdded += 1
        }
        return result
    }

    /// Snapshot a repository into an export document.
    static func snapshot(of repo: SampleRepository, at date: Date) async throws -> ExportDocument {
        ExportDocument(devices: try await repo.profiles(),
                       samples: try await repo.allSamples(),
                       exportedAt: date)
    }
}
