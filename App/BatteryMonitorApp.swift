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
