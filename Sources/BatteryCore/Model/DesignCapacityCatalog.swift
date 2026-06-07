import Foundation

/// Maps known device models to their factory design battery capacity (mAh).
///
/// Used as a fallback when a probe cannot read the design capacity directly off the
/// device. Users can always override the value per device in the app.
public enum DesignCapacityCatalog {
    /// model substring (case-insensitive) -> design capacity in mAh.
    /// Matched by `contains` so regional variants (SM-S931B/U/W…) all resolve.
    public static let table: [(match: String, mAh: Int)] = [
        // Samsung Galaxy S25 family
        ("SM-S931", 4000),   // Galaxy S25
        ("SM-S936", 4900),   // Galaxy S25+
        ("SM-S938", 5000),   // Galaxy S25 Ultra
        ("SM-S937", 3900),   // Galaxy S25 Edge
        // Xiaomi / Poco
        ("M2012K11AG", 4520), // Poco F3 (alioth)
        ("POCO F3", 4520),
    ]

    /// Best-effort design capacity for a model string, or `nil` if unknown.
    public static func capacity(forModel model: String) -> Int? {
        let needle = model.uppercased()
        for entry in table where needle.contains(entry.match.uppercased()) {
            return entry.mAh
        }
        return nil
    }
}
