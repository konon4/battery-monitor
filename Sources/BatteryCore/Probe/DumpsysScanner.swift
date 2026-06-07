import Foundation

/// Tolerant line scanner for `dumpsys battery` style output.
///
/// dumpsys emits `key: value` lines with inconsistent leading whitespace and, on
/// Samsung, bracketed values like `mSavedBatteryAsoc: [96]`. These helpers extract the
/// first match for a key anywhere in the blob.
struct DumpsysScanner {
    let text: String

    init(_ text: String) { self.text = text }

    /// Raw string value for a line that *begins* with `key:` (brackets/whitespace
    /// trimmed), or nil. Prefix-anchored so `voltage` does not match `Max charging
    /// voltage:` and `level` does not match `Capacity level:`.
    func string(_ key: String) -> String? {
        let prefix = key + ":"
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) else { continue }
            var value = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    func int(_ key: String) -> Int? {
        guard let s = string(key) else { return nil }
        // Guard against capturing trailing tokens; take the leading integer.
        let leading = s.prefix { $0.isNumber || $0 == "-" }
        return Int(leading)
    }

    func double(_ key: String) -> Double? {
        guard let s = string(key) else { return nil }
        let leading = s.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(leading)
    }

    /// Parse a compact `yyyyMMdd` field (e.g. Samsung FirstUseDate `20250812`).
    func date_yyyyMMdd(_ key: String) -> Date? {
        guard let s = string(key) else { return nil }
        return Self.yyyyMMdd.date(from: String(s.prefix(8)))
    }

    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()
}
