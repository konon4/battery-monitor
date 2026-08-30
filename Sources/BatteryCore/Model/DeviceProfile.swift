import Foundation

/// Per-device metadata that is stable across samples and persisted once per phone.
public struct DeviceProfile: Hashable, Codable, Sendable, Identifiable {
    public var id: String { identity.serial }
    public let identity: DeviceIdentity

    /// User-facing name (defaults to the model; editable in the app).
    public var label: String
    /// Design capacity in mAh — catalog value, probe-read value, or a user override.
    public var designCapacityMAh: Int?
    /// First power-on date reported by the device (Samsung `FirstUseDate`).
    public var firstUseDate: Date?
    /// Battery cell manufacture date (Samsung `LLB CAL`).
    public var cellManufactureDate: Date?
    /// Cell chemistry — drives the wear-projection curve. Defaults to standard Li-ion.
    public var chemistry: BatteryChemistry
    /// Charge cycles entered by hand, for devices that never report them over ADB
    /// (Xiaomi/MIUI and most non-Samsung Android) — read off the phone's own engineering
    /// menu, e.g. `*#*#6485#*#*` → MB_07. Probe-read counts always take priority.
    public var manualCycleCount: Int?
    /// When ``manualCycleCount`` was entered, so a stale figure can be shown as such.
    public var manualCycleCountDate: Date?

    public init(
        identity: DeviceIdentity,
        label: String? = nil,
        designCapacityMAh: Int? = nil,
        firstUseDate: Date? = nil,
        cellManufactureDate: Date? = nil,
        chemistry: BatteryChemistry = .graphite,
        manualCycleCount: Int? = nil,
        manualCycleCountDate: Date? = nil
    ) {
        self.identity = identity
        self.label = label ?? identity.model
        self.designCapacityMAh = designCapacityMAh ?? DesignCapacityCatalog.capacity(forModel: identity.model)
        self.firstUseDate = firstUseDate
        self.cellManufactureDate = cellManufactureDate
        self.chemistry = chemistry
        self.manualCycleCount = manualCycleCount
        self.manualCycleCountDate = manualCycleCountDate
    }

    /// Name to show in the UI: the user's custom label if set, otherwise the consumer
    /// marketing name (e.g. "Poco F3"), falling back to the raw model.
    public var displayName: String {
        if label != identity.model { return label }                       // user customized
        return DesignCapacityCatalog.marketingName(forModel: identity.model) ?? label
    }

    private enum CodingKeys: String, CodingKey {
        case identity, label, designCapacityMAh, firstUseDate, cellManufactureDate, chemistry
        case manualCycleCount, manualCycleCountDate
    }

    // Custom decode so exports written before `chemistry` existed still import.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identity = try c.decode(DeviceIdentity.self, forKey: .identity)
        label = try c.decode(String.self, forKey: .label)
        designCapacityMAh = try c.decodeIfPresent(Int.self, forKey: .designCapacityMAh)
        firstUseDate = try c.decodeIfPresent(Date.self, forKey: .firstUseDate)
        cellManufactureDate = try c.decodeIfPresent(Date.self, forKey: .cellManufactureDate)
        chemistry = try c.decodeIfPresent(BatteryChemistry.self, forKey: .chemistry) ?? .graphite
        manualCycleCount = try c.decodeIfPresent(Int.self, forKey: .manualCycleCount)
        manualCycleCountDate = try c.decodeIfPresent(Date.self, forKey: .manualCycleCountDate)
    }
}
