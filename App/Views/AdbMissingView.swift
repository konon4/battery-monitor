import SwiftUI
import BatteryCore

struct AdbMissingView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 48)).foregroundStyle(.orange)
            Text("Android Debug Bridge (adb) not found").font(.title2.bold())
            Text("BatteryMonitor talks to phones over adb. Install it once, then reconnect your phone.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            GroupBox("Install with Homebrew") {
                HStack {
                    Text("brew install android-platform-tools")
                        .font(.body.monospaced()).textSelection(.enabled)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("brew install android-platform-tools", forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                }
                .padding(6)
            }
            .frame(maxWidth: 460)

            HStack {
                Button("Choose adb manually…") { picking = true }
                Button("Re-check") { model.locateADB() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.unixExecutable, .item]) { result in
            if case .success(let url) = result { model.customAdbPath = url.path }
        }
    }
}
