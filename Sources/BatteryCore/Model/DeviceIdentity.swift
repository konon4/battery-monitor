import Foundation

/// Stable identity of a physical phone as reported by ADB.
///
/// `serial` is the ADB serial (also the USB serial). The remaining fields come from
/// `getprop` and are used to route the device to the correct ``BatteryProbe``.
public struct DeviceIdentity: Hashable, Codable, Sendable {
    public let serial: String
    public let model: String          // ro.product.model        e.g. "SM-S931B"
    public let codename: String       // ro.product.device        e.g. "pa1q"
    public let manufacturer: String   // ro.product.manufacturer  e.g. "samsung"

    public init(serial: String, model: String, codename: String, manufacturer: String) {
        self.serial = serial
        self.model = model
        self.codename = codename
        self.manufacturer = manufacturer
    }

    public var isSamsung: Bool { manufacturer.lowercased().contains("samsung") }
    public var isXiaomi: Bool {
        let m = manufacturer.lowercased()
        return m.contains("xiaomi") || m.contains("poco") || m.contains("redmi")
    }
}
