import Foundation

/// Routes a connected device to the first ``BatteryProbe`` that supports it.
///
/// Order matters: OEM-specific probes come first, the generic fallback last. To add a
/// new device family, append its probe before `.generic` — nothing else changes.
public struct DeviceRegistry: Sendable {
    public let probes: [any BatteryProbe]

    public init(probes: [any BatteryProbe]) {
        self.probes = probes
    }

    /// The default production registry.
    public static var standard: DeviceRegistry {
        DeviceRegistry(probes: [
            SamsungProbe(),
            XiaomiProbe(),      // Poco / Redmi / Xiaomi (MIUI/HyperOS) via batterystats
            GenericAOSPProbe(), // last-resort fallback (supports everything)
        ])
    }

    public func probe(for id: DeviceIdentity) -> (any BatteryProbe)? {
        probes.first { $0.supports(id) }
    }

    /// Read a sample for a device, selecting the right probe automatically.
    public func read(_ id: DeviceIdentity, via runner: ShellRunner, now: Date) async throws -> ProbeResult {
        guard let probe = probe(for: id) else { throw ProbeError.unsupportedDevice }
        return try await probe.read(id, via: runner, now: now)
    }
}
