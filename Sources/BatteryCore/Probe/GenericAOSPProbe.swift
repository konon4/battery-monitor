import Foundation

/// Fallback probe for any Android device.
///
/// Health source order (best first): sysfs `charge_full / charge_full_design` (cleanest,
/// but root-gated on many OEMs) → `dumpsys batterystats` learned capacity vs. catalog
/// design. Always returns at least a live level so history is never empty.
public struct GenericAOSPProbe: BatteryProbe {
    public init() {}
    public let name = "Generic Android (AOSP)"

    public func supports(_ id: DeviceIdentity) -> Bool { true } // last-resort default

    public func read(_ id: DeviceIdentity, via runner: ShellRunner, now: Date) async throws -> ProbeResult {
        let live = LiveBatteryFields(DumpsysScanner(try await runner.shell(serial: id.serial, "dumpsys battery")))

        var health: Double?
        var estFull: Double?
        var designMAh: Int? = DesignCapacityCatalog.capacity(forModel: id.model)
        var cycleCount: Int?

        // 1) sysfs (best, when readable without root)
        let full = await Self.readSysfsInt(runner, id.serial, "charge_full")
        let fullDesign = await Self.readSysfsInt(runner, id.serial, "charge_full_design")
        cycleCount = await Self.readSysfsInt(runner, id.serial, "cycle_count")

        if let full, let fullDesign, fullDesign > 0 {
            health = Double(full) / Double(fullDesign) * 100.0
            estFull = Double(full) / 1000.0                 // µAh -> mAh
            designMAh = Int((Double(fullDesign) / 1000.0).rounded())
        } else {
            // 2) batterystats learned capacity (root-free fallback)
            let stats = (try? await runner.shell(serial: id.serial, "dumpsys batterystats")) ?? ""
            if let learned = BatteryStatsParser.learnedCapacityMAh(stats) {
                estFull = Double(learned)
                if let design = designMAh, design > 0 {
                    health = min(100, Double(learned) / Double(design) * 100.0)
                }
            }
        }

        let sample = BatterySample(
            deviceSerial: id.serial,
            timestamp: now,
            levelPercent: live.level,
            voltage: live.voltage,
            temperatureC: live.temperatureC,
            chargeCounterMAh: live.chargeCounterMAh,
            currentNowMA: live.currentNowMA,
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
        return Int(out.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
