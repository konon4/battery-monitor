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

    public init(
        identity: DeviceIdentity,
        label: String? = nil,
        designCapacityMAh: Int? = nil,
        firstUseDate: Date? = nil,
        cellManufactureDate: Date? = nil,
        chemistry: BatteryChemistry = .graphite
    ) {
        self.identity = identity
        self.label = label ?? identity.model
        self.designCapacityMAh = designCapacityMAh ?? DesignCapacityCatalog.capacity(forModel: identity.model)
        self.firstUseDate = firstUseDate
        self.cellManufactureDate = cellManufactureDate
        self.chemistry = chemistry
    }

    private enum CodingKeys: String, CodingKey {
        case identity, label, designCapacityMAh, firstUseDate, cellManufactureDate, chemistry
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
    }
}
