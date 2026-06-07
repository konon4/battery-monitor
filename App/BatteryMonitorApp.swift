import SwiftUI
import SwiftData
import BatteryCore

@main
struct BatteryMonitorApp: App {
    let container: ModelContainer
    @State private var model: AppModel

    @MainActor
    init() {
        do {
            container = try ModelContainer(for: DeviceProfileEntity.self, BatterySampleEntity.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        let repo = SwiftDataRepository(context: container.mainContext)
        _model = State(initialValue: AppModel(repo: repo))
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
