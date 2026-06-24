import SwiftUI
import BatteryCore

struct DeviceSidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedSerial) {
            Section("Devices") {
                ForEach(model.profiles) { profile in
                    DeviceRow(profile: profile, state: model.connectionState(for: profile.id))
                        .tag(profile.id as String?)
                }
            }
            let unsaved = model.devices.filter { d in !model.profiles.contains { $0.id == d.serial } }
            if !unsaved.isEmpty {
                Section("Connected (not yet captured)") {
                    ForEach(unsaved, id: \.serial) { d in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(unsavedName(d)).font(.body)
                            Text(d.state.badge.text).font(.caption).foregroundStyle(d.state.badge.color)
                        }
                        .tag(d.serial as String?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func unsavedName(_ d: ADBDevice) -> String {
        guard let model = d.model else { return d.serial }
        return DesignCapacityCatalog.marketingName(forModel: model) ?? model
    }
}

private struct DeviceRow: View {
    let profile: DeviceProfile
    let state: ADBDevice.State?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName).font(.body)
                Text(profile.identity.model).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let state {
                Circle().fill(state.badge.color).frame(width: 8, height: 8)
            }
        }
    }
}
