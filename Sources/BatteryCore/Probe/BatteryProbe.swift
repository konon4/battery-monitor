import Foundation

/// Minimal abstraction over "run a shell command on a device" so the probes can be
/// unit-tested with a fake runner that replays captured `dumpsys` output.
/// ``ADBClient`` is the production implementation.
public protocol ShellRunner: Sendable {
    func shell(serial: String, _ command: String) async throws -> String
}

/// What a probe extracts from a device: the time-series ``BatterySample`` plus the
/// stable profile facts (dates, design capacity) it happened to discover.
public struct ProbeResult: Sendable {
    public var sample: BatterySample
    public var firstUseDate: Date?
    public var cellManufactureDate: Date?
    public var designCapacityMAh: Int?

    public init(sample: BatterySample,
                firstUseDate: Date? = nil,
                cellManufactureDate: Date? = nil,
                designCapacityMAh: Int? = nil) {
        self.sample = sample
        self.firstUseDate = firstUseDate
        self.cellManufactureDate = cellManufactureDate
        self.designCapacityMAh = designCapacityMAh
    }
}

public enum ProbeError: Error, Equatable {
    case unsupportedDevice
    case unreadable(String)
}

/// Strategy for reading battery data from one family of devices.
///
/// Adding a new phone (e.g. Poco F3) means writing one conformer and registering it
/// in ``DeviceRegistry`` — no other layer changes.
public protocol BatteryProbe: Sendable {
    /// Human-readable name shown in the UI / logs.
    var name: String { get }
    /// Whether this probe knows how to read the given device.
    func supports(_ id: DeviceIdentity) -> Bool
    /// Read one sample. `now` is injected for deterministic tests.
    func read(_ id: DeviceIdentity, via runner: ShellRunner, now: Date) async throws -> ProbeResult
}
