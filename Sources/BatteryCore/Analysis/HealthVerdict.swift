import Foundation

/// Coarse health classification for at-a-glance verdicts (e.g. on a customer report).
/// Thresholds follow the common 80%-of-original end-of-life convention.
public enum HealthVerdict: String, Sendable, CaseIterable {
    case good          // ≥ 90%
    case fair          // 80–90%
    case serviceSoon   // < 80%
    case unknown       // no health reading

    public static func from(healthPercent: Double?) -> HealthVerdict {
        guard let h = healthPercent else { return .unknown }
        switch h {
        case 90...:    return .good
        case 80..<90:  return .fair
        default:       return .serviceSoon
        }
    }

    public var label: String {
        switch self {
        case .good:        return "Good"
        case .fair:        return "Fair"
        case .serviceSoon: return "Service soon"
        case .unknown:     return "Unknown"
        }
    }

    /// One-line plain-language guidance for a non-technical customer.
    public var advice: String {
        switch self {
        case .good:        return "Battery is in good health — no action needed."
        case .fair:        return "Some wear, still serviceable. Monitor over the coming months."
        case .serviceSoon: return "Capacity is low — a battery replacement is recommended."
        case .unknown:     return "Not enough data to assess battery health."
        }
    }
}
