import SwiftUI
import Charts
import BatteryCore

/// Everything the one-page report needs (kept explicit so the renderer is pure).
struct BatteryReportData {
    let profile: DeviceProfile
    let sample: BatterySample
    let projection: WearProjection?
    let samples: [BatterySample]
    let shopName: String
    let threshold: Double
    let generatedAt: Date
}

/// US-Letter (612×792 pt) printable battery-health report for a customer.
struct BatteryReportView: View {
    let data: BatteryReportData

    static let pageSize = CGSize(width: 612, height: 792)

    private var verdict: HealthVerdict { HealthVerdict.from(healthPercent: data.sample.healthPercent) }
    private var wear: Double? { data.sample.healthPercent.map { 100 - $0 } }
    private var healthChartPoints: [BatterySample] { data.samples.filter { $0.healthPercent != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            deviceLine
            verdictBanner
            figures
            if !secondary.isEmpty { secondaryGrid }
            if let projection = data.projection { projectionBox(projection) }
            if healthChartPoints.count >= 2 { chart }
            Spacer(minLength: 0)
            footer
        }
        .padding(40)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .topLeading)
        .background(.white)
        .foregroundStyle(.black)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.shopName.isEmpty ? "Battery Health Report" : data.shopName)
                    .font(.system(size: 24, weight: .bold))
                if !data.shopName.isEmpty {
                    Text("Battery Health Report").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Fmt.date.string(from: data.generatedAt))
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var deviceLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(data.profile.label).font(.system(size: 17, weight: .semibold))
            Text("\(data.profile.identity.manufacturer) · \(data.profile.identity.model) · \(data.profile.identity.serial)")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var verdictBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: verdictIcon).font(.system(size: 26)).foregroundStyle(verdictColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.label).font(.system(size: 18, weight: .bold)).foregroundStyle(verdictColor)
                Text(verdict.advice).font(.system(size: 12)).foregroundStyle(.black.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(verdictColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var figures: some View {
        HStack(spacing: 12) {
            figure("Wear", Fmt.pct(wear, digits: 1), "capacity lost")
            figure("Health", Fmt.pct(data.sample.healthPercent), "of original")
            figure("Full capacity", Fmt.mAh(data.sample.estimatedFullCapacityMAh),
                   data.profile.designCapacityMAh.map { "of \($0) mAh new" } ?? "estimated")
        }
    }

    private var secondary: [(String, String)] {
        var out: [(String, String)] = []
        if let bsoh = data.sample.bsoh { out.append(("BSOH", String(format: "%.0f", bsoh))) }
        if let c = data.sample.cycleCount { out.append(("Cycle count", "\(c)")) }
        if let f = data.profile.firstUseDate { out.append(("In service since", Fmt.date.string(from: f))) }
        if let cell = data.profile.cellManufactureDate { out.append(("Cell made", Fmt.date.string(from: cell))) }
        return out
    }

    private var secondaryGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4)
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(secondary, id: \.0) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.0).font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(item.1).font(.system(size: 14, weight: .medium))
                }
            }
        }
    }

    private func projectionBox(_ p: WearProjection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Wear projection").font(.system(size: 13, weight: .semibold))
            HStack(spacing: 20) {
                Text("Reaches \(Int(p.threshold))% health: " +
                     (p.projectedDateToThreshold.map { Fmt.date.string(from: $0) } ?? "—"))
                Text("(" + Fmt.days(p.daysToThreshold) + ")").foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            Text("Model: \(p.modelName) · \(p.confidence.label.lowercased()) confidence · \(p.sampleCount) reading(s)")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.12)))
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Health over time").font(.system(size: 13, weight: .semibold))
            Chart(healthChartPoints) { s in
                LineMark(x: .value("Date", s.timestamp), y: .value("Health %", s.healthPercent ?? 0))
                    .foregroundStyle(.green)
                PointMark(x: .value("Date", s.timestamp), y: .value("Health %", s.healthPercent ?? 0))
                    .foregroundStyle(.green)
            }
            .chartYAxisLabel("%")
            .frame(height: 150)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Divider()
            Text("Health is read from the device over ADB (no root): Samsung ASOC, or the fuel-gauge learned capacity ÷ design capacity. Estimates; not a manufacturer warranty figure.")
                .font(.system(size: 9)).foregroundStyle(.secondary)
            Text("Generated by Battery Monitor · \(Fmt.dateTime.string(from: data.generatedAt))")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    private func figure(_ title: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 26, weight: .bold))
            Text(sub).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var verdictColor: Color {
        switch verdict {
        case .good: return .green
        case .fair: return .orange
        case .serviceSoon: return .red
        case .unknown: return .gray
        }
    }
    private var verdictIcon: String {
        switch verdict {
        case .good: return "checkmark.seal.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .serviceSoon: return "wrench.adjustable.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
