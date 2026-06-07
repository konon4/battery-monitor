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

        let level = s.int("level") ?? 0
        let voltage = s.double("voltage").map { $0 / 1000.0 }            // mV -> V
        let temperature = s.double("temperature").map { $0 / 10.0 }      // 0.1°C -> °C
        let chargeCounter = s.double("Charge counter").map { $0 / 1000.0 } // µAh -> mAh
        let currentNow = s.double("current now").map { $0 / 1000.0 }     // µA -> mA

        let asoc = s.double("mSavedBatteryAsoc")
        let bsoh = s.double("mSavedBatteryBsoh")
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
            levelPercent: level,
            voltage: voltage,
            temperatureC: temperature,
            chargeCounterMAh: chargeCounter,
            currentNowMA: currentNow,
            healthPercent: asoc,
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
