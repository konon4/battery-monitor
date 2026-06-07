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

    public init(
        identity: DeviceIdentity,
        label: String? = nil,
        designCapacityMAh: Int? = nil,
        firstUseDate: Date? = nil,
        cellManufactureDate: Date? = nil
    ) {
        self.identity = identity
        self.label = label ?? identity.model
        self.designCapacityMAh = designCapacityMAh ?? DesignCapacityCatalog.capacity(forModel: identity.model)
        self.firstUseDate = firstUseDate
        self.cellManufactureDate = cellManufactureDate
    }
}
