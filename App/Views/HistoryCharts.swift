import SwiftUI
import Charts
import BatteryCore

struct HistoryCharts: View {
    let samples: [BatterySample]
    let designCapacity: Int?

    private var healthPoints: [BatterySample] { samples.filter { $0.healthPercent != nil } }
    private var capacityPoints: [BatterySample] { samples.filter { $0.estimatedFullCapacityMAh != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if healthPoints.count >= 1 {
                chartBox("Battery health over time") {
                    Chart(healthPoints) { s in
                        LineMark(x: .value("Date", s.timestamp),
                                 y: .value("Health %", s.healthPercent ?? 0))
                        .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", s.timestamp),
                                  y: .value("Health %", s.healthPercent ?? 0))
                    }
                    .chartYScale(domain: yDomain(for: healthPoints.compactMap(\.healthPercent)))
                    .chartYAxisLabel("%")
                    .frame(height: 200)
                }
            }
            if capacityPoints.count >= 1 {
                chartBox("Estimated capacity (mAh)") {
                    Chart(capacityPoints) { s in
                        LineMark(x: .value("Date", s.timestamp),
                                 y: .value("mAh", s.estimatedFullCapacityMAh ?? 0))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.teal)
                        if let design = designCapacity {
                            RuleMark(y: .value("Design", design))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, alignment: .leading) {
                                    Text("design \(design)").font(.caption2).foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private func yDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = max(1, (hi - lo) * 0.2)
        return (max(0, lo - pad))...(min(100, hi + pad))
    }

    private func chartBox<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        GroupBox(title) { content().padding(.top, 4) }
    }
}
