import SwiftUI
import Charts
import BatteryCore

/// A future point sampled from the chemistry fade model.
struct ProjectedPoint: Identifiable { let id = UUID(); let date: Date; let health: Double }

/// Samples the projection's `t^z` curve from the last reading to the projected EOL (capped).
func projectedCurve(_ projection: WearProjection?, from last: Date?) -> [ProjectedPoint] {
    guard let p = projection, let from = last else { return [] }
    let horizonCap = from.addingTimeInterval(6 * 365.25 * 86_400)
    let end = min(p.projectedDate ?? horizonCap, horizonCap)
    guard end > from else { return [] }
    var out: [ProjectedPoint] = []
    var d = from
    let step: TimeInterval = 15 * 86_400
    while d <= end { if let h = p.healthPercent(at: d) { out.append(.init(date: d, health: h)) }; d += step }
    if let h = p.healthPercent(at: end) { out.append(.init(date: end, health: h)) }
    return out
}

struct HistoryCharts: View {
    let samples: [BatterySample]
    let designCapacity: Int?
    let projection: WearProjection?
    let threshold: Double

    private var healthPoints: [BatterySample] { samples.filter { $0.healthPercent != nil } }
    private var capacityPoints: [BatterySample] { samples.filter { $0.estimatedFullCapacityMAh != nil } }
    private var projected: [ProjectedPoint] { projectedCurve(projection, from: healthPoints.last?.timestamp) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !healthPoints.isEmpty {
                GroupBox("Battery health over time") {
                    HealthChartView(points: healthPoints, projected: projected, threshold: threshold)
                        .padding(.top, 4)
                }
            }
            if !capacityPoints.isEmpty {
                GroupBox("Estimated capacity (mAh)") {
                    CapacityChartView(points: capacityPoints, projected: projected, design: designCapacity)
                        .padding(.top, 4)
                }
            }
        }
    }
}

/// Health % over time: measured points (line only when ≥2), dashed model projection, EOL line.
struct HealthChartView: View {
    let points: [BatterySample]
    let projected: [ProjectedPoint]
    let threshold: Double

    var body: some View {
        Chart {
            ForEach(projected) { p in
                LineMark(x: .value("Date", p.date), y: .value("Health %", p.health),
                         series: .value("s", "projected"))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            RuleMark(y: .value("EOL", threshold))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(.red.opacity(0.5))
                .annotation(position: .bottom, alignment: .leading) {
                    Text("\(Int(threshold))%").font(.caption2).foregroundStyle(.red.opacity(0.7))
                }
            if points.count >= 2 {
                ForEach(points) { s in
                    LineMark(x: .value("Date", s.timestamp), y: .value("Health %", s.healthPercent ?? 0),
                             series: .value("s", "measured"))
                    .foregroundStyle(.green)
                }
            }
            ForEach(points) { s in
                PointMark(x: .value("Date", s.timestamp), y: .value("Health %", s.healthPercent ?? 0))
                    .foregroundStyle(.green)
            }
        }
        .chartYScale(domain: domain)
        .chartYAxisLabel("%")
        .frame(height: 200)
    }

    private var domain: ClosedRange<Double> {
        let measured = points.compactMap(\.healthPercent)
        let lo = min(threshold - 5, (measured.min() ?? 100) - 3, (projected.map(\.health).min() ?? 100) - 3)
        return max(0, lo)...100
    }
}

/// Estimated capacity over time: fixed 0…design Y-axis (no auto-stretch), dashed projection, design line.
struct CapacityChartView: View {
    let points: [BatterySample]
    let projected: [ProjectedPoint]
    let design: Int?

    var body: some View {
        Chart {
            if let design {
                ForEach(projected) { p in
                    LineMark(x: .value("Date", p.date),
                             y: .value("mAh", p.health / 100 * Double(design)),
                             series: .value("s", "projected"))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                RuleMark(y: .value("Design", design))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("design \(design)").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            if points.count >= 2 {
                ForEach(points) { s in
                    LineMark(x: .value("Date", s.timestamp),
                             y: .value("mAh", s.estimatedFullCapacityMAh ?? 0),
                             series: .value("s", "measured"))
                    .foregroundStyle(.teal)
                }
            }
            ForEach(points) { s in
                PointMark(x: .value("Date", s.timestamp),
                          y: .value("mAh", s.estimatedFullCapacityMAh ?? 0))
                    .foregroundStyle(.teal)
            }
        }
        .chartYScale(domain: 0...Double(design ?? 5000) * 1.05)
        .frame(height: 200)
    }
}
