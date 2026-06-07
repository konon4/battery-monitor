import SwiftUI
import UniformTypeIdentifiers
import BatteryCore

/// JSON file wrapper for export/import dialogs.
struct JSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportFile = JSONFile(data: Data())
    @State private var showSettings = false

    var body: some View {
        @Bindable var model = model
        Group {
            if model.adbState == .missing {
                AdbMissingView()
            } else {
                NavigationSplitView {
                    DeviceSidebar()
                        .frame(minWidth: 220)
                } detail: {
                    if model.selectedSerial != nil {
                        DeviceDetailView()
                    } else {
                        ContentUnavailableView("No device selected",
                                               systemImage: "bolt.batteryblock",
                                               description: Text("Plug in an Android phone with USB debugging enabled, or pick a saved device."))
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if let serial = model.selectedSerial {
                        Task { await model.capture(serial: serial) }
                    }
                } label: { Label("Capture", systemImage: "arrow.clockwise") }
                .disabled(model.selectedSerial == nil || model.isBusy)

                Button { startExport() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                Button { showImporter = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .fileExporter(isPresented: $showExporter, document: exportFile,
                      contentType: .json,
                      defaultFilename: "battery-history-\(Int(Date().timeIntervalSince1970)).json") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { importFrom(url) }
        }
        .safeAreaInset(edge: .bottom) { StatusBar() }
    }

    private func startExport() {
        guard let data = model.exportData() else { return }
        exportFile = JSONFile(data: data)
        showExporter = true
    }

    private func importFrom(_ url: URL) {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url) { model.importData(data) }
    }
}

private struct StatusBar: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 8) {
            if model.isBusy { ProgressView().controlSize(.small) }
            if let error = model.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(error).foregroundStyle(.secondary).lineLimit(1)
            } else if let status = model.statusMessage {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(status).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if case .ready(let path) = model.adbState {
                Text(path).font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.bar)
    }
}
