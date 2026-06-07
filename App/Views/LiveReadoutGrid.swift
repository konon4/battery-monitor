import SwiftUI
import BatteryCore

struct LiveReadoutGrid: View {
    let sample: BatterySample?
    let profile: DeviceProfile?

    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ts = sample?.timestamp {
                Text("Latest reading · \(Fmt.dateTime.string(from: ts))")
                    .font(.headline)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(title: "Charge level", value: sample.map { "\($0.levelPercent)%" } ?? "—",
                         tint: healthColor(sample.map { Double($0.levelPercent) }))
                StatTile(title: "Health (ASOC)", value: Fmt.pct(sample?.healthPercent),
                         tint: healthColor(sample?.healthPercent), emphasis: true)
                StatTile(title: "Est. capacity",
                         value: capacityText, subtitle: designText)
                StatTile(title: "BSOH", value: sample?.bsoh.map { String(format: "%.0f", $0) } ?? "—",
                         subtitle: "Good/Normal bucket")
                StatTile(title: "Temperature", value: Fmt.temp(sample?.temperatureC))
                StatTile(title: "Voltage", value: Fmt.volts(sample?.voltage))
                StatTile(title: "Charge counter", value: Fmt.mAh(sample?.chargeCounterMAh))
                StatTile(title: "Cycle count", value: sample?.cycleCount.map(String.init) ?? "—")
            }
        }
    }

    private var capacityText: String { Fmt.mAh(sample?.estimatedFullCapacityMAh) }
    private var designText: String {
        profile?.designCapacityMAh.map { "of \($0) mAh design" } ?? ""
    }
}

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
