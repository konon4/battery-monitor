import Foundation

/// The on-device source a probe used to obtain ``BatterySample/healthPercent``.
///
/// Recorded at capture (and exported) because the sources differ in nature: ASOC is the
/// fuel gauge's own wear figure, while the capacity ratios are estimates whose
/// denominator comes from ``DesignCapacityCatalog`` or sysfs.
public enum HealthSource: String, Codable, Sendable, Hashable {
    case samsungASOC           // Samsung mSavedBatteryAsoc — direct, granular
    case sysfsChargeFull       // sysfs charge_full ÷ charge_full_design
    case batterystatsLearned   // batterystats learned capacity ÷ catalog design
    case derived               // computed downstream (no probe emits this yet)
}

/// A single point-in-time battery reading for a device.
///
/// This is the core record persisted into history, exported, and fed to the wear models.
/// All optional fields gracefully absent when a given OEM does not expose them over ADB.
public struct BatterySample: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public let deviceSerial: String
    public let timestamp: Date

    /// Live charge level 0–100 (`level`/`scale` from dumpsys).
    public let levelPercent: Int
    /// Battery voltage in volts (dumpsys reports mV).
    public let voltage: Double?
    /// Temperature in °C (dumpsys reports tenths of a degree).
    public let temperatureC: Double?
    /// Live charge counter in mAh (dumpsys reports µAh).
    public let chargeCounterMAh: Double?
    /// Instantaneous current in mA (dumpsys reports µA); sign per device convention.
    public let currentNowMA: Double?

    /// **Headline health metric.** Samsung ASOC (0–100). On the S25 this is the value
    /// that actually degrades (96 = ~4% wear). For generic devices this is derived from
    /// `charge_full / charge_full_design`.
    public let healthPercent: Double?
    /// How ``healthPercent`` was read off the device. `nil` on samples captured before
    /// this field existed (display falls back to inferring from the manufacturer).
    public let healthSource: HealthSource?
    /// Samsung BSOH — coarse Good/Normal/Service bucket (e.g. 100.00). Secondary signal.
    public let bsoh: Double?
    /// Charge cycle count, when the device exposes it (S25 does not over ADB).
    public let cycleCount: Int?

    /// `healthPercent% × designCapacity`, when both are known.
    public let estimatedFullCapacityMAh: Double?

    public init(
        id: UUID = UUID(),
        deviceSerial: String,
        timestamp: Date,
        levelPercent: Int,
        voltage: Double? = nil,
        temperatureC: Double? = nil,
        chargeCounterMAh: Double? = nil,
        currentNowMA: Double? = nil,
        healthPercent: Double? = nil,
        healthSource: HealthSource? = nil,
        bsoh: Double? = nil,
        cycleCount: Int? = nil,
        estimatedFullCapacityMAh: Double? = nil
    ) {
        self.id = id
        self.deviceSerial = deviceSerial
        self.timestamp = timestamp
        self.levelPercent = levelPercent
        self.voltage = voltage
        self.temperatureC = temperatureC
        self.chargeCounterMAh = chargeCounterMAh
        self.currentNowMA = currentNowMA
        self.healthPercent = healthPercent
        self.healthSource = healthSource
        self.bsoh = bsoh
        self.cycleCount = cycleCount
        self.estimatedFullCapacityMAh = estimatedFullCapacityMAh
    }
}
