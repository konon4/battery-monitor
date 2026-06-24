import SwiftUI
import BatteryCore

struct WearPanel: View {
    @Environment(AppModel.self) private var model
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
                    metric("Fading at", String(format: "≈ %.1f%%/yr", projection.ratePerYearPercent),
                           sub: "at current age")
                    metric("Reaches \(Int(projection.threshold))%",
                           projection.projectedDate.map { Fmt.date.string(from: $0) } ?? "—",
                           sub: rangeText)
                }

                HStack(spacing: 6) {
                    Text("Chemistry: \(projection.chemistry.shortLabel)")
                    Text("· \(basisText)")
                    Text("· \(projection.sampleCount) reading\(projection.sampleCount == 1 ? "" : "s")")
                }
                .font(.caption).foregroundStyle(.tertiary)

                Text(disclaimer)
                    .font(.caption).foregroundStyle(.secondary)

                if projection.basis == .typicalCurveNoDate {
                    Button {
                        model.presentSettings = true
                    } label: {
                        Label("Set first-use date for an accurate projection", systemImage: "calendar.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(8)
        }
    }

    private var rangeText: String {
        guard let early = projection.projectedDateEarly, let late = projection.projectedDateLate else {
            return "in " + Fmt.days(projection.daysToThreshold)
        }
        return "range \(Fmt.date.string(from: early)) – \(Fmt.date.string(from: late))"
    }

    private var basisText: String {
        switch projection.basis {
        case .fitted:             return "fitted to your readings"
        case .anchoredToReading:  return "typical \(projection.chemistry.shortLabel) curve through last reading"
        case .typicalCurveNoDate: return "typical curve (set first-use date for accuracy)"
        }
    }

    private var disclaimer: String {
        var s = "Estimate using a \(projection.chemistry.shortLabel) calendar+cycle aging curve (SOH ≈ 1 − α·tᶻ). "
        switch projection.basis {
        case .fitted: s += "Refines as more readings accumulate; a degradation “knee” can accelerate loss below ~85%."
        case .anchoredToReading, .typicalCurveNoDate:
            s += "Limited data — refines automatically as you capture more measurements."
        }
        if projection.chemistry.isUncertain {
            s += " Silicon cells have little public longevity data — treat as approximate."
        }
        return s
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
