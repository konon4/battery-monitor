import Foundation

/// Storage abstraction for device profiles and their battery samples.
///
/// BatteryCore depends only on this protocol; the app provides a SwiftData-backed
/// implementation, while tests use ``InMemorySampleRepository``.
public protocol SampleRepository: Sendable {
    func profiles() async throws -> [DeviceProfile]
    func upsert(profile: DeviceProfile) async throws

    func allSamples() async throws -> [BatterySample]
    func samples(forDevice serial: String) async throws -> [BatterySample]
    func add(sample: BatterySample) async throws

    /// Whether a sample already exists for this device within `window` seconds of `date`
    /// (used to debounce auto-capture).
    func hasSample(forDevice serial: String, near date: Date, window: TimeInterval) async throws -> Bool
}

/// Simple actor-backed in-memory store. Production-safe for tests and previews.
public actor InMemorySampleRepository: SampleRepository {
    private var profileByID: [String: DeviceProfile] = [:]
    private var samplesByID: [String: [BatterySample]] = [:]

    public init(profiles: [DeviceProfile] = [], samples: [BatterySample] = []) {
        for p in profiles { profileByID[p.id] = p }
        for s in samples { samplesByID[s.deviceSerial, default: []].append(s) }
    }

    public func profiles() -> [DeviceProfile] { Array(profileByID.values) }
    public func upsert(profile: DeviceProfile) { profileByID[profile.id] = profile }

    public func allSamples() -> [BatterySample] { samplesByID.values.flatMap { $0 } }

    public func samples(forDevice serial: String) -> [BatterySample] {
        (samplesByID[serial] ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    public func add(sample: BatterySample) {
        samplesByID[sample.deviceSerial, default: []].append(sample)
    }

    public func hasSample(forDevice serial: String, near date: Date, window: TimeInterval) -> Bool {
        (samplesByID[serial] ?? []).contains { abs($0.timestamp.timeIntervalSince(date)) <= window }
    }
}
