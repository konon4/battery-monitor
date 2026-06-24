import SwiftUI
import SwiftData
import Foundation
import BatteryCore

@main
struct BatteryMonitorApp: App {
    let container: ModelContainer
    @State private var model: AppModel

    @MainActor
    init() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()   // exits the process
        }
        if CommandLine.arguments.contains("--report-test") {
            ReportSelfTest.run()   // exits the process
        }
        if CommandLine.arguments.contains("--charts-test") {
            ChartsSelfTest.run()   // exits the process
        }
        do {
            container = try Self.makeContainer()
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        let repo = SwiftDataRepository(context: container.mainContext)
        _model = State(initialValue: AppModel(repo: repo))
    }

    /// Explicit, named store under Application Support (deterministic location).
    static func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([DeviceProfileEntity.self, BatterySampleEntity.self])
        let storeURL = url ?? defaultStoreURL()
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: config)
    }

    static func defaultStoreURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL.temporaryDirectory
        let dir = base.appendingPathComponent("BatteryMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("BatteryMonitor.store")
    }

    var body: some Scene {
        Window("Battery Monitor", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 560)
        }
        .modelContainer(container)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarContent()
                .environment(model)
                .frame(width: 320)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Headless verification of the SwiftData persistence path in the real app target.
/// Run with `swift run battery-monitor --selftest`.
enum SelfTest {
    @MainActor
    static func run() -> Never {
        do {
            let tmp = URL.temporaryDirectory.appendingPathComponent("bm-selftest-\(ProcessInfo.processInfo.processIdentifier).store")
            let container = try BatteryMonitorApp.makeContainer(url: tmp)
            let repo = SwiftDataRepository(context: container.mainContext)

            let id = DeviceIdentity(serial: "SELFTEST1", model: "SM-S931B", codename: "pa1q", manufacturer: "samsung")
            try repo.upsert(profile: DeviceProfile(identity: id, firstUseDate: Date()))
            try repo.add(sample: BatterySample(deviceSerial: "SELFTEST1", timestamp: Date(),
                                               levelPercent: 66, healthPercent: 96,
                                               estimatedFullCapacityMAh: 3840))
            try repo.add(sample: BatterySample(deviceSerial: "SELFTEST1", timestamp: Date().addingTimeInterval(60),
                                               levelPercent: 70, healthPercent: 96))

            let profiles = try repo.profiles()
            let samples = try repo.samples(forDevice: "SELFTEST1")
            let dup = try repo.hasSample(forDevice: "SELFTEST1", near: samples[0].timestamp, window: 5)

            print("SELFTEST profiles=\(profiles.count) samples=\(samples.count) dedupHit=\(dup)")
            try? FileManager.default.removeItem(at: tmp)

            let ok = profiles.count == 1 && samples.count == 2 && dup == true
            print(ok ? "SELFTEST: PASS" : "SELFTEST: FAIL")
            exit(ok ? 0 : 1)
        } catch {
            print("SELFTEST: ERROR \(error)")
            exit(2)
        }
    }
}

/// Headless render of the redesigned HistoryCharts to a PNG for visual review. `--charts-test`.
enum ChartsSelfTest {
    @MainActor
    static func run() -> Never {
        let firstUse = Date().addingTimeInterval(-300 * 86_400)
        let samples = [
            BatterySample(deviceSerial: "d", timestamp: firstUse.addingTimeInterval(60 * 86_400),
                          levelPercent: 70, healthPercent: 98, estimatedFullCapacityMAh: 3920),
            BatterySample(deviceSerial: "d", timestamp: Date(),
                          levelPercent: 66, healthPercent: 96, estimatedFullCapacityMAh: 3840),
        ]
        let projection = WearEstimator().project(samples: samples, firstUseDate: firstUse,
                                                 chemistry: .graphite, now: Date())
        let size = CGSize(width: 800, height: 520)
        let proj = projectedCurve(projection, from: samples.last?.timestamp)
        let view = VStack(alignment: .leading, spacing: 24) {
            Text("Battery health over time").font(.headline)
            HealthChartView(points: samples, projected: proj, threshold: 80)
            Text("Estimated capacity (mAh)").font(.headline)
            CapacityChartView(points: samples, projected: proj, design: 4000)
        }
            .padding(20).frame(width: size.width, height: size.height).background(.white)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        let pdf = NSMutableData()
        renderer.render { _, ctxClosure in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdf as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil); ctxClosure(ctx); ctx.endPDFPage(); ctx.closePDF()
        }
        let url = URL.temporaryDirectory.appendingPathComponent("charts-test.pdf")
        try? (pdf as Data).write(to: url)
        print("CHARTS-TEST: PASS bytes=\(pdf.count) → \(url.path)")
        exit(0)
    }
}

/// Headless verification that the PDF report renders. `--report-test`.
enum ReportSelfTest {
    @MainActor
    static func run() -> Never {
        let id = DeviceIdentity(serial: "REPORT-TEST", model: "SM-S931B", codename: "pa1q", manufacturer: "samsung")
        let firstUse = Date().addingTimeInterval(-300 * 86_400)
        let profile = DeviceProfile(identity: id, firstUseDate: firstUse)
        let samples = [
            BatterySample(deviceSerial: id.serial, timestamp: Date().addingTimeInterval(-90 * 86_400),
                          levelPercent: 80, healthPercent: 98, estimatedFullCapacityMAh: 3920),
            BatterySample(deviceSerial: id.serial, timestamp: Date(),
                          levelPercent: 66, voltage: 4.11, temperatureC: 30, healthPercent: 96,
                          bsoh: 100, estimatedFullCapacityMAh: 3840),
        ]
        let projection = WearEstimator().project(samples: samples, firstUseDate: firstUse,
                                                 chemistry: .graphite, now: Date())
        let data = BatteryReportData(profile: profile, sample: samples[1], projection: projection,
                                     samples: samples, shopName: "Kardan Repair",
                                     threshold: 80, generatedAt: Date())
        guard let pdf = ReportRenderer.pdf(BatteryReportView(data: data)) else {
            print("REPORT-TEST: FAIL (nil pdf)"); exit(1)
        }
        let isPDF = pdf.starts(with: Array("%PDF".utf8))
        let url = URL.temporaryDirectory.appendingPathComponent("battery-report-test.pdf")
        try? pdf.write(to: url)
        print("REPORT-TEST: \(isPDF && pdf.count > 1000 ? "PASS" : "FAIL") bytes=\(pdf.count) → \(url.path)")
        exit(isPDF && pdf.count > 1000 ? 0 : 1)
    }
}
