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

/// PDF wrapper for the customer report exporter.
struct PDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
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
    @State private var showReportExporter = false
    @State private var reportFile = PDFFile(data: Data())
    // Settings presentation lives on the model so deep-links (e.g. from the wear panel) can open it.

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.connectionPhase {
            case .adbMissing, .searching:
                ConnectionGuideView()
            default:
                NavigationSplitView {
                    DeviceSidebar()
                        .frame(minWidth: 220)
                } detail: {
                    if model.selectedSerial != nil && model.selectedHasHistory {
                        DeviceDetailView()
                            .safeAreaInset(edge: .top) {
                                if isProblemPhase { ConnectionBanner() }
                            }
                    } else {
                        ConnectionGuideView()
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

                Button { buildReport() } label: { Label("Report", systemImage: "doc.richtext") }
                    .disabled(!model.selectedHasHistory)
                Button { startExport() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                Button { showImporter = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                Button { model.presentSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .sheet(isPresented: $model.presentSettings) { SettingsSheet() }
        .fileExporter(isPresented: $showExporter, document: exportFile,
                      contentType: .json,
                      defaultFilename: "battery-history-\(Int(Date().timeIntervalSince1970)).json") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { importFrom(url) }
        }
        .fileExporter(isPresented: $showReportExporter, document: reportFile,
                      contentType: .pdf, defaultFilename: reportFilename) { _ in }
        .safeAreaInset(edge: .bottom) { StatusBar() }
    }

    private var isProblemPhase: Bool {
        switch model.connectionPhase {
        case .unauthorized, .offline: return true
        default: return false
        }
    }

    private func startExport() {
        guard let data = model.exportData() else { return }
        exportFile = JSONFile(data: data)
        showExporter = true
    }

    private var reportFilename: String {
        let name = (model.selectedProfile?.label ?? "device")
            .replacingOccurrences(of: " ", with: "-")
        return "battery-report-\(name).pdf"
    }

    private func buildReport() {
        guard let profile = model.selectedProfile, let sample = model.latestSample else { return }
        let data = BatteryReportData(
            profile: profile, sample: sample, projection: model.projection,
            samples: model.samples, shopName: model.shopName,
            threshold: model.wearThreshold, generatedAt: Date())
        guard let pdf = ReportRenderer.pdf(BatteryReportView(data: data)) else {
            model.errorMessage = "Could not generate the report."; return
        }
        reportFile = PDFFile(data: pdf)
        showReportExporter = true
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
