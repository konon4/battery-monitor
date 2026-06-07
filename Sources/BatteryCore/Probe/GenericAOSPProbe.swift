import Foundation

/// Fallback probe for any Android device.
///
/// Strategy: try the cleanest cross-OEM wear metric first —
/// `charge_full / charge_full_design` from sysfs (readable without root on some devices) —
/// and fall back to `dumpsys battery` for live level/voltage/temperature when sysfs is
/// locked down. Always returns at least a level so history is never empty.
public struct GenericAOSPProbe: BatteryProbe {
    public init() {}
    public let name = "Generic Android (AOSP)"

    public func supports(_ id: DeviceIdentity) -> Bool { true } // last-resort default

    public func read(_ id: DeviceIdentity, via runner: ShellRunner, now: Date) async throws -> ProbeResult {
        let dump = try await runner.shell(serial: id.serial, "dumpsys battery")
        let s = DumpsysScanner(dump)

        let level = s.int("level") ?? 0
        let voltage = s.double("voltage").map { $0 / 1000.0 }
        let temperature = s.double("temperature").map { $0 / 10.0 }
        let chargeCounter = s.double("Charge counter").map { $0 / 1000.0 }

        // Best-effort sysfs read for true capacity-based health. Empty/garbage -> nil.
        let full = await Self.readSysfsInt(runner, id.serial, "charge_full")
        let fullDesign = await Self.readSysfsInt(runner, id.serial, "charge_full_design")
        let cycleCount = await Self.readSysfsInt(runner, id.serial, "cycle_count")

        var health: Double?
        var estFull: Double?
        var designMAh: Int? = DesignCapacityCatalog.capacity(forModel: id.model)

        if let full, let fullDesign, fullDesign > 0 {
            health = Double(full) / Double(fullDesign) * 100.0
            estFull = Double(full) / 1000.0          // µAh -> mAh
            designMAh = Int((Double(fullDesign) / 1000.0).rounded())
        } else if let design = designMAh, let asoc = health {
            estFull = asoc / 100.0 * Double(design)
        }

        let sample = BatterySample(
            deviceSerial: id.serial,
            timestamp: now,
            levelPercent: level,
            voltage: voltage,
            temperatureC: temperature,
            chargeCounterMAh: chargeCounter,
            currentNowMA: s.double("current now").map { $0 / 1000.0 },
            healthPercent: health,
            bsoh: nil,
            cycleCount: cycleCount,
            estimatedFullCapacityMAh: estFull
        )
        return ProbeResult(sample: sample, designCapacityMAh: designMAh)
    }

    private static func readSysfsInt(_ runner: ShellRunner, _ serial: String, _ node: String) async -> Int? {
        let path = "/sys/class/power_supply/battery/\(node)"
        guard let out = try? await runner.shell(serial: serial, "cat \(path) 2>/dev/null") else { return nil }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }
}
