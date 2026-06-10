import SwiftUI
import BatteryCore

// MARK: - Battery health (durable — valid even when the phone is unplugged)

/// The primary panel: wear / health / capacity. These are persistent battery properties,
/// so the last captured values stay meaningful after disconnect.
struct HealthSummary: View {
    let sample: BatterySample?
    let profile: DeviceProfile?

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) }
    private var wear: Double? { sample?.healthPercent.map { 100 - $0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Battery health", systemImage: "cross.case").font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "Wear", value: Fmt.pct(wear, digits: 1),
                         subtitle: "capacity lost", tint: wearColor(wear), emphasis: true)
                StatTile(title: "Health (ASOC)", value: Fmt.pct(sample?.healthPercent),
                         subtitle: "of original", tint: healthColor(sample?.healthPercent), emphasis: true)
                StatTile(title: "Full capacity", value: Fmt.mAh(sample?.estimatedFullCapacityMAh),
                         subtitle: designText, emphasis: true)
            }
            // Secondary durable facts, only when the device reports them.
            let extras = healthExtras
            if !extras.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(extras, id: \.0) { StatTile(title: $0.0, value: $0.1, subtitle: $0.2) }
                }
            }
        }
    }

    private var designText: String {
        profile?.designCapacityMAh.map { "of \($0) mAh when new" } ?? "estimated"
    }

    private var healthExtras: [(String, String, String)] {
        var out: [(String, String, String)] = []
        if let bsoh = sample?.bsoh { out.append(("BSOH", String(format: "%.0f", bsoh), "Good/Normal bucket")) }
        if let cycles = sample?.cycleCount { out.append(("Cycle count", "\(cycles)", "charge cycles")) }
        if let first = profile?.firstUseDate {
            out.append(("In service", Fmt.relative.localizedString(for: first, relativeTo: Date()), "since \(Fmt.date.string(from: first))"))
        }
        return out
    }
}

// MARK: - Live readings (volatile — a snapshot from the last capture)

/// Instantaneous values that are only true while connected. When the phone is unplugged
/// the section is dimmed and relabeled as a timestamped snapshot, so stale numbers aren't
/// mistaken for the current state.
struct LiveReadings: View {
    let sample: BatterySample?
    let isConnected: Bool

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if isConnected {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Live readings").font(.headline)
                } else {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                    Text("Last reading").font(.headline)
                }
                if let ts = sample?.timestamp {
                    Text("· \(Fmt.relative.localizedString(for: ts, relativeTo: Date()))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if !isConnected {
                    Text("phone disconnected").font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "Charge level", value: sample.map { "\($0.levelPercent)%" } ?? "—",
                         tint: isConnected ? healthColor(sample.map { Double($0.levelPercent) }) : .secondary)
                StatTile(title: "Voltage", value: Fmt.volts(sample?.voltage))
                StatTile(title: "Temperature", value: Fmt.temp(sample?.temperatureC))
                StatTile(title: "Current charge", value: Fmt.mAh(sample?.chargeCounterMAh),
                         subtitle: "charge stored")
                StatTile(title: "Current draw", value: Fmt.milliamps(sample?.currentNowMA),
                         subtitle: "instantaneous")
            }
            .opacity(isConnected ? 1 : 0.5)
            if !isConnected {
                Text("Reconnect the phone for live values.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Tile

struct StatTile: View {
    let title: String
    let value: String
    var subtitle: String = ""
    var tint: Color = .primary
    var emphasis: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(emphasis ? .title.bold() : .title2.weight(.medium))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            if !subtitle.isEmpty {
                Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Wear color ramp (inverse of health): low wear = green, high wear = red.
func wearColor(_ wear: Double?) -> Color {
    guard let wear else { return .secondary }
    return healthColor(100 - wear)
}
