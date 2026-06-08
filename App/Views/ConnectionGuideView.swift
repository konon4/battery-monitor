import SwiftUI
import BatteryCore

/// Step-by-step connection assistant. The four steps light up live as the user installs
/// adb, plugs in the phone, enables USB debugging, and taps Allow — driven by
/// `AppModel.connectionPhase`, which updates on USB hot-plug and the 8s poll.
struct ConnectionGuideView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                VStack(spacing: 0) {
                    StepRow(index: 1, title: "Install Android Debug Bridge (adb)",
                            status: adbStatus, isLast: false) { AdbStep() }
                    StepRow(index: 2, title: "Connect your phone over USB",
                            status: connectStatus, isLast: false) { ConnectStep() }
                    StepRow(index: 3, title: "Enable USB debugging",
                            status: debuggingStatus, isLast: false) { DebuggingStep() }
                    StepRow(index: 4, title: "Authorize this Mac",
                            status: authorizeStatus, isLast: true) { AuthorizeStep() }
                }
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 54, height: 54)
                Image(systemName: phaseIcon).font(.title).foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, isActive: model.connectionPhase != .ready)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Connect a phone").font(.title.bold())
                Text(phaseSubtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            ProgressView().controlSize(.small).opacity(model.connectionPhase == .ready ? 0 : 1)
        }
    }

    // MARK: Step statuses derived from the live phase

    private var adbStatus: ConnectionStepStatus { model.adbState == .missing ? .current : .done }
    private var connectStatus: ConnectionStepStatus {
        if model.adbState == .missing { return .pending }
        return model.devices.isEmpty ? .current : .done
    }
    private var debuggingStatus: ConnectionStepStatus {
        switch model.connectionPhase {
        case .ready: return .done
        case .unauthorized, .offline: return .done   // debugging is clearly on
        case .noDevice where !model.devices.isEmpty: return .current
        default: return .pending
        }
    }
    private var authorizeStatus: ConnectionStepStatus {
        switch model.connectionPhase {
        case .ready: return .done
        case .unauthorized, .offline: return .current
        default: return .pending
        }
    }

    private var phaseIcon: String {
        switch model.connectionPhase {
        case .ready: return "checkmark.circle.fill"
        case .adbMissing: return "wrench.and.screwdriver"
        case .unauthorized: return "lock.open"
        case .offline: return "exclamationmark.triangle"
        default: return "cable.connector"
        }
    }
    private var phaseSubtitle: String {
        switch model.connectionPhase {
        case .searching: return "Looking for adb…"
        case .adbMissing: return "First, install adb (one-time setup)."
        case .noDevice: return "Plug in your Android phone to begin."
        case .unauthorized: return "Almost there — confirm the prompt on your phone."
        case .offline: return "Device is offline — reconnect the cable."
        case .ready: return "Connected! Reading battery…"
        }
    }
}

// MARK: - Step scaffold

private struct StepRow<Content: View>: View {
    let index: Int
    let title: String
    let status: ConnectionStepStatus
    let isLast: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                marker
                if !isLast {
                    Rectangle().fill(.quaternary).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(status == .pending ? .secondary : .primary)
                if status == .current { content() }
            }
            .padding(.bottom, isLast ? 0 : 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.top, 16)
    }

    @ViewBuilder private var marker: some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
        case .current:
            ZStack {
                Circle().fill(Color.accentColor).frame(width: 24, height: 24)
                Text("\(index)").font(.caption.bold()).foregroundStyle(.white)
            }
        case .pending:
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 2).frame(width: 24, height: 24)
                Text("\(index)").font(.caption.bold()).foregroundStyle(.secondary)
            }
        }
    }
}

enum ConnectionStepStatus { case done, current, pending }

// MARK: - Step bodies

private struct AdbStep: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BatteryMonitor talks to phones through adb. Install it once with Homebrew:")
                .foregroundStyle(.secondary)
            HStack {
                Text("brew install android-platform-tools")
                    .font(.callout.monospaced()).textSelection(.enabled)
                    .padding(8).background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("brew install android-platform-tools", forType: .string)
                } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).help("Copy")
            }
            HStack {
                Button("Choose adb manually…") { picking = true }
                Button("Re-check") { model.locateADB() }.buttonStyle(.borderedProminent)
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.unixExecutable, .item]) { result in
            if case .success(let url) = result { model.customAdbPath = url.path }
        }
    }
}

private struct ConnectStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Plug the phone into this Mac with a USB cable.", systemImage: "cable.connector")
            Label("On the phone, set the USB mode to **File transfer / MTP** (not “Charging only”).",
                  systemImage: "arrow.up.arrow.down")
        }
        .foregroundStyle(.secondary)
    }
}

private struct DebuggingStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            stepLine("1.", "Settings → **About phone → Software information**")
            stepLine("2.", "Tap **Build number** 7 times to unlock Developer options")
            stepLine("3.", "Settings → **Developer options** → turn on **USB debugging**")
        }
        .foregroundStyle(.secondary)
    }
    private func stepLine(_ n: String, _ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(n).font(.callout.monospacedDigit()).foregroundStyle(.tertiary)
            Text(.init(t))
        }
    }
}

private struct AuthorizeStep: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .offline = model.connectionPhase {
                Label("The phone shows as offline. Unplug and replug the cable, or toggle USB debugging off/on.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "iphone.gen3.badge.exclamationmark")
                        .font(.system(size: 34)).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Look at your phone").font(.headline)
                        Text("A dialog **“Allow USB debugging?”** is waiting. Check **“Always allow from this computer”** and tap **Allow**.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                Text("Don’t see it? Unlock the phone, or in Developer options tap **Revoke USB debugging authorizations**, then replug.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
