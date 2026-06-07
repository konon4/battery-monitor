import SwiftUI
import BatteryCore

struct WearPanel: View {
    let projection: WearProjection

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Wear projection", systemImage: "chart.line.downtrend.xyaxis")
                        .font(.headline)
                    Spacer()
                    Text(projection.confidence.label + " confidence")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(projection.confidence.color.opacity(0.18), in: Capsule())
                        .foregroundStyle(projection.confidence.color)
                }

                HStack(alignment: .top, spacing: 24) {
                    metric("Current wear", Fmt.pct(projection.wearPercent, digits: 1),
                           sub: "health \(Fmt.pct(projection.currentHealthPercent))")
                    metric("Degrading at", String(format: "%.3f%%/day", projection.ratePerDay),
                           sub: String(format: "≈ %.1f%%/yr", projection.ratePerDay * 365.25))
                    metric("Reaches \(Int(projection.threshold))%",
                           projection.projectedDateToThreshold.map { Fmt.date.string(from: $0) } ?? "—",
                           sub: "in " + Fmt.days(projection.daysToThreshold))
                }

                HStack(spacing: 6) {
                    Text("Model: \(projection.modelName)")
                    if let r2 = projection.r2 { Text(String(format: "· R² %.3f", r2)) }
                    Text("· \(projection.sampleCount) sample\(projection.sampleCount == 1 ? "" : "s")")
                }
                .font(.caption).foregroundStyle(.tertiary)

                if projection.confidence == .low {
                    Text("Estimate from limited data — it refines automatically as more measurements are captured.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private func metric(_ title: String, _ value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold))
            Text(sub).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
