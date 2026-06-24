import Foundation
import Observation
import BatteryCore

/// Top-level UI state and orchestration: adb discovery, device polling/hot-plug,
/// capture, persistence, and wear projection. Views observe this; all logic flows
/// through BatteryCore protocols so it stays testable and device-agnostic.
@MainActor
@Observable
final class AppModel {
    enum AdbState: Equatable { case searching, missing, ready(String) }

    private(set) var adbState: AdbState = .searching
    var devices: [ADBDevice] = []                 // live `adb devices`
    private(set) var profiles: [DeviceProfile] = [] // known/persisted devices
    private(set) var samples: [BatterySample] = []  // history for the selection
    private(set) var projection: WearProjection?
    var statusMessage: String?
    var errorMessage: String?
    private(set) var isBusy = false

    var selectedSerial: String? { didSet { loadSelected() } }

    var customAdbPath: String? {
        didSet {
            UserDefaults.standard.set(customAdbPath, forKey: Keys.adbPath)
            locateADB()
        }
    }
    var wearThreshold: Double {
        didSet {
            UserDefaults.standard.set(wearThreshold, forKey: Keys.threshold)
            recomputeProjection()
        }
    }

    /// Shop name printed on the customer PDF report (branding).
    var shopName: String {
        didSet { UserDefaults.standard.set(shopName, forKey: Keys.shopName) }
    }

    private enum Keys {
        static let adbPath = "customAdbPath"
        static let threshold = "wearThreshold"
        static let shopName = "shopName"
    }
    private let autoCaptureWindow: TimeInterval = 30 * 60   // de-dup auto captures within 30 min

    private var adb: ADBClient?
    private let repo: SwiftDataRepository
    private let registry = DeviceRegistry.standard
    private let monitor = ConnectionMonitor()
    private var pollTask: Task<Void, Never>?

    init(repo: SwiftDataRepository) {
        self.repo = repo
        self.customAdbPath = UserDefaults.standard.string(forKey: Keys.adbPath)
        let stored = UserDefaults.standard.double(forKey: Keys.threshold)
        self.wearThreshold = stored == 0 ? 80 : stored
        self.shopName = UserDefaults.standard.string(forKey: Keys.shopName) ?? ""

        locateADB()
        loadProfiles()
        if selectedSerial == nil { selectedSerial = profiles.first?.id }

        monitor.onChange = { [weak self] in Task { await self?.refreshDevices() } }
        monitor.start()
        startPolling()
    }

    // MARK: Derived

    var selectedProfile: DeviceProfile? { profiles.first { $0.id == selectedSerial } }
    var latestSample: BatterySample? { samples.last }

    func connectionState(for serial: String) -> ADBDevice.State? {
        devices.first { $0.serial == serial }?.state
    }

    func latestSample(for serial: String) -> BatterySample? {
        (try? repo.samples(forDevice: serial))?.last
    }

    /// Overall connection state, used to drive the onboarding/guidance UI.
    enum ConnectionPhase: Equatable {
        case searching          // locating adb
        case adbMissing         // adb not installed
        case noDevice           // adb ok, nothing plugged in
        case unauthorized(String)
        case offline(String)
        case ready              // at least one authorized device
    }

    var connectionPhase: ConnectionPhase {
        switch adbState {
        case .searching: return .searching
        case .missing: return .adbMissing
        case .ready:
            if devices.contains(where: { $0.isReady }) { return .ready }
            if let u = devices.first(where: { $0.state == .unauthorized }) { return .unauthorized(u.serial) }
            if let o = devices.first(where: { $0.state == .offline }) { return .offline(o.serial) }
            return .noDevice
        }
    }

    var hasReadyDevice: Bool { devices.contains { $0.isReady } }
    var selectedHasHistory: Bool { !samples.isEmpty }

    // MARK: adb discovery

    func locateADB() {
        if let path = AdbLocator.discover(customPath: customAdbPath) {
            adb = ADBClient(adbPath: path)
            adbState = .ready(path)
        } else {
            adb = nil
            adbState = .missing
        }
    }

    // MARK: Polling / hot-plug

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshDevices()
                try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
            }
        }
    }

    func refreshDevices() async {
        guard let adb else { return }
        do {
            let list = try await adb.listDevices()
            self.devices = list
            for d in list where d.isReady {
                await autoCapture(serial: d.serial)
            }
            if selectedSerial == nil { selectedSerial = profiles.first?.id ?? list.first?.serial }
        } catch {
            report(error)
        }
    }

    // MARK: Capture

    private func autoCapture(serial: String) async {
        guard let recent = try? repo.hasSample(forDevice: serial, near: Date(), window: autoCaptureWindow),
              recent == false else { return }
        await capture(serial: serial, silent: true)
    }

    @discardableResult
    func capture(serial: String, silent: Bool = false) async -> Bool {
        guard let adb else { errorMessage = "adb not found."; return false }
        isBusy = true
        defer { isBusy = false }
        do {
            let identity = try await adb.identity(serial: serial)
            let result = try await registry.read(identity, via: adb, now: Date())

            // Merge discovered facts into the profile, preserving user edits.
            var profile = profiles.first { $0.id == serial } ?? DeviceProfile(identity: identity)
            profile.firstUseDate = profile.firstUseDate ?? result.firstUseDate
            profile.cellManufactureDate = profile.cellManufactureDate ?? result.cellManufactureDate
            if profile.designCapacityMAh == nil { profile.designCapacityMAh = result.designCapacityMAh }
            try repo.upsert(profile: profile)
            try repo.add(sample: result.sample)

            loadProfiles()
            if serial == selectedSerial { loadSelected() }
            if !silent {
                statusMessage = "Captured \(profile.label): \(result.sample.levelPercent)%"
                    + (result.sample.healthPercent.map { ", health \(Int($0))%" } ?? "")
            }
            return true
        } catch {
            report(error)
            return false
        }
    }

    // MARK: Loading

    func loadProfiles() {
        profiles = ((try? repo.profiles()) ?? []).sorted { $0.label < $1.label }
    }

    private func loadSelected() {
        guard let serial = selectedSerial else { samples = []; projection = nil; return }
        samples = (try? repo.samples(forDevice: serial)) ?? []
        recomputeProjection()
    }

    private func recomputeProjection() {
        guard let profile = selectedProfile else { projection = nil; return }
        projection = WearEstimator(threshold: wearThreshold)
            .project(samples: samples, firstUseDate: profile.firstUseDate,
                     chemistry: profile.chemistry, now: Date())
    }

    func updateProfile(_ profile: DeviceProfile) {
        try? repo.upsert(profile: profile)
        loadProfiles()
        loadSelected()
    }

    // MARK: Export / Import

    func exportData() -> Data? {
        do { return try makeSnapshot().jsonData() }
        catch { report(error); return nil }
    }

    private func makeSnapshot() throws -> ExportDocument {
        ExportDocument(devices: try repo.profiles(),
                       samples: try repo.allSamples(),
                       exportedAt: Date())
    }

    func importData(_ data: Data) {
        do {
            let doc = try ExportDocument.decode(data)
            let result = try mergeSync(doc)
            loadProfiles()
            if selectedSerial == nil { selectedSerial = profiles.first?.id }
            loadSelected()
            statusMessage = "Imported \(result.samplesAdded) samples"
                + (result.samplesSkipped > 0 ? " (\(result.samplesSkipped) duplicates skipped)" : "")
        } catch {
            report(error)
        }
    }

    /// Synchronous merge against the main-actor repository (mirrors `ExportDocument.merge`).
    private func mergeSync(_ doc: ExportDocument) throws -> MergeResult {
        var result = MergeResult(devicesAdded: 0, samplesAdded: 0, samplesSkipped: 0)
        let existing = Set(try repo.profiles().map(\.id))
        for device in doc.devices {
            if !existing.contains(device.id) { result.devicesAdded += 1 }
            try repo.upsert(profile: device)
        }
        func key(_ s: String, _ t: Date) -> String { "\(s)|\(t.timeIntervalSince1970)" }
        var seen = Set(try repo.allSamples().map { key($0.deviceSerial, $0.timestamp) })
        for sample in doc.samples {
            let k = key(sample.deviceSerial, sample.timestamp)
            if seen.contains(k) { result.samplesSkipped += 1; continue }
            seen.insert(k)
            try repo.add(sample: sample)
            result.samplesAdded += 1
        }
        return result
    }

    // MARK: Errors

    private func report(_ error: Error) {
        if let adbError = error as? ADBError {
            switch adbError {
            case .adbNotFound: errorMessage = "adb not found. Install it or set the path in Settings."
            case .deviceUnauthorized: errorMessage = "Device unauthorized — tap “Allow USB debugging” on the phone."
            case .deviceOffline: errorMessage = "Device offline — unplug/replug the cable."
            case .noDevices: errorMessage = "No device connected."
            case .timeout: errorMessage = "adb timed out."
            case .shellFailed(_, let stderr): errorMessage = "adb error: \(stderr)"
            case .launchFailed(let m): errorMessage = "Could not launch adb: \(m)"
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }

    func shutdown() {
        pollTask?.cancel()
        monitor.stop()
    }
}
