import SwiftUI
import BatteryCore

struct DeviceDetailView: View {
    @Environment(AppModel.self) private var model

    private var isConnected: Bool {
        guard let serial = model.selectedSerial else { return false }
        return model.connectionState(for: serial) == .device
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let profile = model.selectedProfile {
                    header(profile)
                }
                if model.samples.isEmpty {
                    emptyState
                } else {
                    // 1) Durable health (valid even when disconnected) — the headline.
                    HealthSummary(sample: model.latestSample, profile: model.selectedProfile)
                    // 2) Wear projection.
                    if let projection = model.projection {
                        WearPanel(projection: projection)
                    } else {
                        needsMoreDataPanel
                    }
                    // 3) Volatile live readings — clearly a snapshot when offline.
                    LiveReadings(sample: model.latestSample, isConnected: isConnected)
                    // 4) History.
                    HistoryCharts(samples: model.samples,
                                  designCapacity: model.selectedProfile?.designCapacityMAh)
                }
            }
            .padding(20)
        }
    }

    private func header(_ profile: DeviceProfile) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.label).font(.largeTitle.bold())
                Text("\(profile.identity.manufacturer) · \(profile.identity.model) · \(profile.identity.serial)")
                    .font(.callout).foregroundStyle(.secondary)
                if let first = profile.firstUseDate {
                    Text("In service since \(Fmt.date.string(from: first))")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            let badge = model.connectionState(for: profile.id)?.badge
                ?? (text: "Disconnected", color: Color.secondary)
            Label(badge.text, systemImage: "circle.fill")
                .font(.caption).foregroundStyle(badge.color)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(badge.color.opacity(0.12), in: Capsule())
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No measurements yet", systemImage: "battery.0percent")
        } description: {
            Text("Connect the phone and press Capture to take the first reading.")
        } actions: {
            if let serial = model.selectedSerial {
                Button("Capture now") { Task { await model.capture(serial: serial) } }
                    .disabled(model.isBusy)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var needsMoreDataPanel: some View {
        GroupBox {
            Label("Need a first-use date or at least one health reading to project wear.",
                  systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        }
    }
}
