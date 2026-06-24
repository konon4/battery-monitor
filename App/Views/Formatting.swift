import SwiftUI
import BatteryCore

enum Fmt {
    static let date: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    static let dateTime: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    static func pct(_ v: Double?, digits: Int = 0) -> String {
        guard let v else { return "—" }
        return String(format: "%.\(digits)f%%", v)
    }
    static func mAh(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f mAh", v)
    }
    static func volts(_ v: Double?) -> String { v.map { String(format: "%.3f V", $0) } ?? "—" }
    static func milliamps(_ v: Double?) -> String { v.map { String(format: "%.0f mA", $0) } ?? "—" }

    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full; return f
    }()

    /// Elapsed duration as a plain span without "ago", e.g. "10 months", "1.8 years".
    static func duration(since date: Date, to now: Date = Date()) -> String {
        let days = max(0, now.timeIntervalSince(date) / 86_400)
        if days < 60 { return "\(Int(days.rounded())) days" }
        if days < 365 { return "\(Int((days / 30.44).rounded())) months" }
        return String(format: "%.1f years", days / 365.25)
    }
    static func temp(_ v: Double?) -> String { v.map { String(format: "%.1f °C", $0) } ?? "—" }
    static func days(_ v: Double?) -> String {
        guard let v else { return "—" }
        if v >= 365 { return String(format: "%.1f yr", v / 365.25) }
        return String(format: "%.0f days", v)
    }
}

extension WearProjection.Confidence {
    var label: String { rawValue.capitalized }
    var color: Color {
        switch self { case .low: return .orange; case .medium: return .yellow; case .high: return .green }
    }
}

/// Color ramp for a health/level percentage.
func healthColor(_ pct: Double?) -> Color {
    guard let pct else { return .secondary }
    switch pct {
    case 90...:   return .green
    case 80..<90: return .mint
    case 60..<80: return .yellow
    case 40..<60: return .orange
    default:      return .red
    }
}

extension ADBDevice.State {
    var badge: (text: String, color: Color) {
        switch self {
        case .device:       return ("Connected", .green)
        case .unauthorized: return ("Unauthorized", .orange)
        case .offline:      return ("Offline", .red)
        case .unknown:      return ("Unknown", .secondary)
        }
    }
}
