import Foundation

/// Battery cell chemistry — drives the capacity-fade curve shape and rate.
///
/// Fade is modelled as `SOH(t) = 1 − α · t^z` (t = battery age in years), the holistic
/// power-law form (Schmalstieg et al. 2014 use z≈0.75 for NMC). Pure SEI-limited calendar
/// aging is z=0.5 (√t); cycle aging pushes the effective exponent up toward linear, so the
/// per-chemistry `z`/`alphaPrior` below are *combined* (calendar+cycle) engineering priors
/// for typical phone use, not pure-calendar coefficients. Ranges give the uncertainty band.
public enum BatteryChemistry: String, Codable, Sendable, CaseIterable {
    case graphite        // standard Li-ion / Li-poly (graphite anode, NMC/LCO cathode)
    case highVoltage     // cells charged to 4.4–4.48 V (most modern flagships) — faster fade
    case lfp             // LiFePO4 — flat, very long cycle life
    case siliconCarbon   // Si / Si-C anode (2023+ high-density cells) — steeper, knee, uncertain

    /// Fade exponent z in `SOH = 1 − α·t^z`.
    public var exponent: Double {
        switch self {
        case .graphite:      return 0.75   // Schmalstieg holistic NMC
        case .highVoltage:   return 0.75
        case .lfp:           return 0.55   // calendar-dominated, flatter
        case .siliconCarbon: return 0.85   // steeper-early, less decelerating
        }
    }

    /// Typical fade coefficient α (loss fraction at t = 1 year). Center of the prior.
    public var alphaPrior: Double {
        switch self {
        case .graphite:      return 0.045
        case .highVoltage:   return 0.060
        case .lfp:           return 0.012
        case .siliconCarbon: return 0.070
        }
    }

    /// Plausible α band (slow … fast use) used for the projection's uncertainty range and clamp.
    public var alphaRange: ClosedRange<Double> {
        switch self {
        case .graphite:      return 0.030...0.080
        case .highVoltage:   return 0.040...0.100
        case .lfp:           return 0.006...0.025
        case .siliconCarbon: return 0.040...0.120
        }
    }

    // MARK: - Cycle life

    /// Typical charge cycles to the industry-standard 80 %-of-original end of life.
    /// This is the figure phone makers publish (e.g. "80 % capacity after 800 cycles")
    /// and the anchor for the cycle projection's prior.
    public var ratedCycles: Int {
        switch self {
        case .graphite:      return 800
        case .highVoltage:   return 600    // 4.4 V+ cells trade cycle life for energy
        case .lfp:           return 2500   // conservative vs. the 3000+ often claimed
        case .siliconCarbon: return 800    // vendors claim 1000+, little independent data
        }
    }

    /// Plausible band of cycles-to-80 % (heavy … gentle use). Clamps the fitted rate so a
    /// single early reading cannot extrapolate to an absurd cycle life.
    public var ratedCyclesRange: ClosedRange<Int> {
        switch self {
        case .graphite:      return 500...1600
        case .highVoltage:   return 400...1200
        case .lfp:           return 1500...4000
        case .siliconCarbon: return 400...1400
        }
    }

    /// Exponent w in `loss(n) = beta * n^w` (n = equivalent full cycles). ~1 means the
    /// published "linear to 80 %" convention; >1 leans to a late-life knee, <1 flattens.
    public var cycleExponent: Double {
        switch self {
        case .graphite:      return 1.00
        case .highVoltage:   return 1.05
        case .lfp:           return 0.90
        case .siliconCarbon: return 1.10
        }
    }

    public var label: String {
        switch self {
        case .graphite:      return "Li-ion / Li-poly (standard)"
        case .highVoltage:   return "High-voltage Li-ion (4.4 V+)"
        case .lfp:           return "LiFePO₄ (LFP)"
        case .siliconCarbon: return "Silicon / Si-C"
        }
    }

    public var shortLabel: String {
        switch self {
        case .graphite:      return "Li-ion"
        case .highVoltage:   return "HV Li-ion"
        case .lfp:           return "LFP"
        case .siliconCarbon: return "Si-C"
        }
    }

    /// Whether projections for this chemistry carry extra uncertainty (no verified phone-cell data).
    public var isUncertain: Bool { self == .siliconCarbon }

    /// Best-effort default from the `technology` string dumpsys reports.
    /// Li-poly is just a form factor (same graphite chemistry), so both map to `.graphite`.
    /// Silicon/HV cannot be detected over ADB — the user picks those in Settings.
    public static func `default`(forTechnology technology: String?) -> BatteryChemistry {
        let t = (technology ?? "").lowercased()
        if t.contains("lifepo") || t.contains("lfp") { return .lfp }
        return .graphite
    }
}
