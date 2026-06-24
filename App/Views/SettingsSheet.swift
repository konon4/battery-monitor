import SwiftUI
import UniformTypeIdentifiers
import BatteryCore

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pickingAdb = false

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings").font(.title2.bold()).padding()
            Divider()
            Form {
                Section("Selected device") {
                    if let profile = model.selectedProfile {
                        DeviceSettingsEditor(profile: profile) { model.updateProfile($0) }
                    } else {
                        Text("No device selected").foregroundStyle(.secondary)
                    }
                }

                Section("Customer report") {
                    TextField("Shop name", text: $model.shopName, prompt: Text("e.g. Kardan Repair"))
                    Text("Printed as the header on the exported PDF battery report.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Wear model") {
                    Stepper(value: $model.wearThreshold, in: 50...95, step: 1) {
                        Text("End-of-life threshold: \(Int(model.wearThreshold))% health")
                    }
                    Text("Projections estimate when the battery reaches this health level.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("ADB") {
                    LabeledContent("Status") {
                        switch model.adbState {
                        case .ready(let path): Text(path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        case .missing: Text("Not found").foregroundStyle(.orange)
                        case .searching: Text("Searching…").foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button("Choose adb…") { pickingAdb = true }
                        if model.customAdbPath != nil {
                            Button("Reset to auto-detect") { model.customAdbPath = nil }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }.padding()
        }
        .frame(width: 520, height: 460)
        .fileImporter(isPresented: $pickingAdb, allowedContentTypes: [.unixExecutable, .executable, .item]) { result in
            if case .success(let url) = result { model.customAdbPath = url.path }
        }
    }
}

private struct DeviceSettingsEditor: View {
    @State var profile: DeviceProfile
    let onSave: (DeviceProfile) -> Void

    var body: some View {
        TextField("Label", text: $profile.label)
            .onSubmit { onSave(profile) }
        TextField("Design capacity (mAh)", value: Binding(
            get: { profile.designCapacityMAh ?? 0 },
            set: { profile.designCapacityMAh = $0 == 0 ? nil : $0 }), format: .number)
            .onSubmit { onSave(profile) }
        DatePicker("First use date",
                   selection: Binding(get: { profile.firstUseDate ?? Date() },
                                      set: { profile.firstUseDate = $0 }),
                   displayedComponents: .date)
        Button("Save") { onSave(profile) }
    }
}
