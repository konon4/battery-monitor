import Foundation

/// Reads battery health from Xiaomi / Redmi / Poco devices (MIUI / HyperOS).
///
/// MIUI locks `/sys/class/power_supply/**` behind root (even `uevent`), and `dumpsys
/// battery` omits health. The one root-free signal is the fuel-gauge's *learned* full
/// capacity from `dumpsys batterystats`, compared against the catalog design capacity.
///
/// Not available over ADB without root: charge cycle count (use dialer `*#*#6485#*#`),
/// manufacture / first-use dates.
public struct XiaomiProbe: BatteryProbe {
    public init() {}
    public let name = "Xiaomi (MIUI/HyperOS)"

    public func supports(_ id: DeviceIdentity) -> Bool { id.isXiaomi }

    public func read(_ id: DeviceIdentity, via runner: ShellRunner, now: Date) async throws -> ProbeResult {
        let live = LiveBatteryFields(DumpsysScanner(try await runner.shell(serial: id.serial, "dumpsys battery")))
        let stats = (try? await runner.shell(serial: id.serial, "dumpsys batterystats")) ?? ""

        let learned = BatteryStatsParser.learnedCapacityMAh(stats)
        let design = DesignCapacityCatalog.capacity(forModel: id.model)

        var health: Double?
        if let learned, let design, design > 0 {
            health = min(100, Double(learned) / Double(design) * 100)
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
            cycleCount: nil,
            estimatedFullCapacityMAh: learned.map(Double.init)
        )
        return ProbeResult(sample: sample, designCapacityMAh: design)
    }
}
