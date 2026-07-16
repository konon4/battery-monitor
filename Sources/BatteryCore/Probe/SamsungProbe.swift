import Foundation

/// Reads battery health from Samsung Galaxy devices via `dumpsys battery`.
///
/// Samsung One UI exposes the values that are region-locked in the Settings UI:
/// - `mSavedBatteryAsoc`  — ASOC, the granular health % (headline wear metric)
/// - `mSavedBatteryBsoh`  — coarse Good/Normal/Service health bucket
/// - `battery FirstUseDate` (`yyyyMMdd`)
/// - `LLB CAL`            — battery cell manufacture date (`yyyyMMdd`)
public struct SamsungProbe: BatteryProbe {
    public init() {}
    public let name = "Samsung (One UI)"

    public func supports(_ id: DeviceIdentity) -> Bool { id.isSamsung }

    public func read(_ id: DeviceIdentity, via runner: ShellRunner, now: Date) async throws -> ProbeResult {
        let dump = try await runner.shell(serial: id.serial, "dumpsys battery")
        return Self.parse(dump, identity: id, now: now)
    }

    /// Pure parser — the unit-tested heart of the probe.
    static func parse(_ dump: String, identity id: DeviceIdentity, now: Date) -> ProbeResult {
        let s = DumpsysScanner(dump)
        let live = LiveBatteryFields(s)

        // Exynos and some A/M-series firmwares report ASOC/BSOH as -1 ("not supported") —
        // treat non-positive values as absent rather than storing a -1% health reading.
        let asoc = s.double("mSavedBatteryAsoc").flatMap { $0 > 0 ? $0 : nil }
        let bsoh = s.double("mSavedBatteryBsoh").flatMap { $0 > 0 ? $0 : nil }
        let firstUse = s.date_yyyyMMdd("battery FirstUseDate")
        let cellDate = s.date_yyyyMMdd("LLB CAL")

        let design = DesignCapacityCatalog.capacity(forModel: id.model)
        let estFull: Double? = {
            guard let asoc, let design else { return nil }
            return asoc / 100.0 * Double(design)
        }()

        let sample = BatterySample(
            deviceSerial: id.serial,
            timestamp: now,
            levelPercent: live.level,
            voltage: live.voltage,
            temperatureC: live.temperatureC,
            chargeCounterMAh: live.chargeCounterMAh,
            currentNowMA: live.currentNowMA,
            healthPercent: asoc,
            healthSource: asoc.map { _ in .samsungASOC },
            bsoh: bsoh,
            cycleCount: nil,   // S25 reports cycle_count: 0 over ADB — not trustworthy, omit.
            estimatedFullCapacityMAh: estFull
        )

        return ProbeResult(
            sample: sample,
            firstUseDate: firstUse,
            cellManufactureDate: cellDate,
            designCapacityMAh: design
        )
    }
}
