import SwiftUI
import BatteryCore

/// Slim, always-visible banner that surfaces a connected-but-unusable device (the common
/// "unauthorized" case) even while the user is looking at saved history.
struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let info = info {
            HStack(spacing: 10) {
                Image(systemName: info.icon).foregroundStyle(info.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.title).font(.callout.weight(.semibold))
                    Text(info.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Show steps") { model.selectedSerial = info.serial }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(info.tint.opacity(0.12))
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private struct Info { let serial, title, detail, icon: String; let tint: Color }

    private var info: Info? {
        switch model.connectionPhase {
        case .unauthorized(let serial):
            return Info(serial: serial,
                        title: "Tap “Allow” on your phone",
                        detail: "A USB-debugging prompt is waiting — check “Always allow”, then Allow.",
                        icon: "lock.open.fill", tint: .orange)
        case .offline(let serial):
            return Info(serial: serial,
                        title: "Phone is offline",
                        detail: "Unplug and replug the USB cable to reconnect.",
                        icon: "exclamationmark.triangle.fill", tint: .red)
        default:
            return nil
        }
    }
}
