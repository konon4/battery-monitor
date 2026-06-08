import Foundation
import BatteryCore

// Headless companion to the app: exercises the exact production read path
// (ADBClient → DeviceRegistry → BatteryProbe) and prints the resulting sample as JSON.
// Usage: bmprobe [serial]   (defaults to the first ready device)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

let adb: ADBClient
do { adb = try ADBClient.locate() } catch { fail("adb not found — install android-platform-tools") }

let devices = (try? await adb.listDevices()) ?? []
guard !devices.isEmpty else { fail("no devices connected") }

let target: ADBDevice
if let arg = CommandLine.arguments.dropFirst().first {
    guard let match = devices.first(where: { $0.serial == arg }) else { fail("serial \(arg) not found") }
    target = match
} else {
    guard let ready = devices.first(where: { $0.isReady }) else {
        fail("no authorized device (states: \(devices.map { "\($0.serial)=\($0.state.rawValue)" }.joined(separator: ", ")))")
    }
    target = ready
}

print("Device: \(target.serial)  state=\(target.state.rawValue)  model=\(target.model ?? "?")")

do {
    let identity = try await adb.identity(serial: target.serial)
    print("Identity: \(identity.manufacturer) / \(identity.model) / \(identity.codename)")

    let result = try await DeviceRegistry.standard.read(identity, via: adb, now: Date())
    print("Probe: \(DeviceRegistry.standard.probe(for: identity)?.name ?? "?")")
    if let first = result.firstUseDate { print("First use: \(first)") }
    if let cell = result.cellManufactureDate { print("Cell mfg: \(cell)") }
    if let design = result.designCapacityMAh { print("Design capacity: \(design) mAh") }

    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    enc.dateEncodingStrategy = .iso8601
    print("\nSample:")
    print(String(decoding: try enc.encode(result.sample), as: UTF8.self))
} catch {
    fail("\(error)")
}
