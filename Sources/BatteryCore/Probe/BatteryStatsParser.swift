import Foundation

/// Extracts capacity figures from `dumpsys batterystats` output.
///
/// AOSP's BatteryStats exposes the fuel-gauge's *learned* full capacity without root —
/// the cleanest wear signal available on devices (e.g. MIUI/HyperOS) that lock down
/// `/sys/class/power_supply`. Example lines:
///
///     Estimated battery capacity: 3636 mAh   (power-profile / rolling estimate)
///     Last learned battery capacity: 4132 mAh (fuel-gauge charge_full — preferred)
///     Min learned battery capacity: 4132 mAh
///     Max learned battery capacity: 4132 mAh
enum BatteryStatsParser {
    /// The fuel-gauge learned full capacity (mAh): prefers "Last learned", then Max, then Min.
    static func learnedCapacityMAh(_ text: String) -> Int? {
        firstInt(text, after: "Last learned battery capacity:")
            ?? firstInt(text, after: "Max learned battery capacity:")
            ?? firstInt(text, after: "Min learned battery capacity:")
    }

    /// The power-profile / estimated capacity (mAh).
    static func estimatedCapacityMAh(_ text: String) -> Int? {
        firstInt(text, after: "Estimated battery capacity:")
    }

    private static func firstInt(_ text: String, after marker: String) -> Int? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let r = line.range(of: marker) else { continue }
            let tail = line[r.upperBound...]
            let digits = tail.drop { !$0.isNumber }.prefix { $0.isNumber }
            if let v = Int(digits) { return v }
        }
        return nil
    }
}
