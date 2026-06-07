import SwiftUI
import BatteryCore

/// Compact menu-bar label: a bolt + the connected device's level/health, if any.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let connected = model.profiles.first { model.connectionState(for: $0.id) == .device }
        let latest = connected.flatMap { model.latestSample(for: $0.id) }
        HStack(spacing: 4) {
            Image(systemName: "bolt.batteryblock.fill")
            if let latest { Text("\(latest.levelPercent)%") }
        }
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery Monitor").font(.headline)
            Divider()

            if model.adbState == .missing {
                Label("adb not found", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if model.devices.isEmpty {
                Text("No device connected").foregroundStyle(.secondary)
            } else {
                ForEach(model.devices, id: \.serial) { d in
                    HStack {
                        Circle().fill(d.state.badge.color).frame(width: 8, height: 8)
                        Text(d.model ?? d.serial)
                        Spacer()
                        if d.isReady {
                            Button("Capture") { Task { await model.capture(serial: d.serial) } }
                                .buttonStyle(.borderless).disabled(model.isBusy)
                        } else {
                            Text(d.state.badge.text).font(.caption).foregroundStyle(d.state.badge.color)
                        }
                    }
                }
            }

            Divider()
            Button("Open Battery Monitor") { openWindow(id: "main"); activate() }
            Button("Quit") { model.shutdown(); NSApplication.shared.terminate(nil) }
        }
        .padding(12)
    }

    private func activate() { NSApplication.shared.activate(ignoringOtherApps: true) }
}
