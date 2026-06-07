import Foundation

/// Actor-isolated wrapper around the `adb` executable.
///
/// Serialises all subprocess access (one `adb` invocation at a time), drains stdout/stderr
/// concurrently to avoid pipe-buffer deadlock on large `dumpsys` output, and enforces a
/// timeout. Conforms to ``ShellRunner`` so probes can run against it or a fake.
public actor ADBClient: ShellRunner {
    public let adbPath: String
    public let defaultTimeout: TimeInterval

    public init(adbPath: String, defaultTimeout: TimeInterval = 20) {
        self.adbPath = adbPath
        self.defaultTimeout = defaultTimeout
    }

    /// Convenience: locate adb or throw `.adbNotFound`.
    public static func locate(customPath: String? = nil, timeout: TimeInterval = 20) throws -> ADBClient {
        guard let path = AdbLocator.discover(customPath: customPath) else { throw ADBError.adbNotFound }
        return ADBClient(adbPath: path, defaultTimeout: timeout)
    }

    public func listDevices() async throws -> [ADBDevice] {
        Self.parseDevices(try await run(["devices", "-l"]))
    }

    public func identity(serial: String) async throws -> DeviceIdentity {
        let out = try await run(["-s", serial, "shell",
            "getprop ro.product.model; getprop ro.product.device; getprop ro.product.manufacturer"])
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func at(_ i: Int) -> String { i < lines.count ? lines[i] : "" }
        return DeviceIdentity(serial: serial, model: at(0), codename: at(1), manufacturer: at(2))
    }

    public func shell(serial: String, _ command: String) async throws -> String {
        try await run(["-s", serial, "shell", command])
    }

    // MARK: - Process execution

    func run(_ args: [String], timeout: TimeInterval? = nil) async throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: adbPath)
        proc.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        // Drain pipes concurrently so a >64KB dump never blocks the child on a full buffer.
        async let outData = Self.readToEnd(outPipe.fileHandleForReading)
        async let errData = Self.readToEnd(errPipe.fileHandleForReading)

        do { try proc.run() } catch { throw ADBError.launchFailed(error.localizedDescription) }

        let limit = timeout ?? defaultTimeout
        let watchdog = Task { () -> Bool in
            try? await Task.sleep(nanoseconds: UInt64(limit * 1_000_000_000))
            if Task.isCancelled { return false }
            if proc.isRunning { proc.terminate(); return true }
            return false
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            proc.terminationHandler = { _ in cont.resume() }
        }
        let didTimeout = await watchdog.value
        watchdog.cancel()

        let stdout = String(decoding: await outData, as: UTF8.self)
        let stderr = String(decoding: await errData, as: UTF8.self)

        if didTimeout { throw ADBError.timeout(command: args.joined(separator: " ")) }

        if proc.terminationStatus != 0 {
            try Self.mapError(stderr: stderr, args: args)
            throw ADBError.shellFailed(code: proc.terminationStatus,
                                       stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return stdout
    }

    private nonisolated static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }

    // MARK: - Parsing

    static func parseDevices(_ output: String) -> [ADBDevice] {
        var result: [ADBDevice] = []
        for line in output.split(separator: "\n").dropFirst() {  // skip "List of devices attached"
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("*") { continue }
            let cols = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard cols.count >= 2 else { continue }
            let state = ADBDevice.State(rawValue: cols[1]) ?? .unknown
            let model = cols.first { $0.hasPrefix("model:") }
                .map { String($0.dropFirst("model:".count)).replacingOccurrences(of: "_", with: "-") }
            result.append(ADBDevice(serial: cols[0], state: state, model: model))
        }
        return result
    }

    static func mapError(stderr: String, args: [String]) throws {
        let s = stderr.lowercased()
        let serial = (args.firstIndex(of: "-s").map { $0 + 1 }).flatMap { $0 < args.count ? args[$0] : nil } ?? ""
        if s.contains("unauthorized") { throw ADBError.deviceUnauthorized(serial: serial) }
        if s.contains("offline") { throw ADBError.deviceOffline(serial: serial) }
        if s.contains("no devices") || s.contains("device not found") { throw ADBError.noDevices }
    }
}
