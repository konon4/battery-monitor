import Foundation

public enum ADBError: Error, Equatable, Sendable {
    case adbNotFound
    case deviceUnauthorized(serial: String)
    case deviceOffline(serial: String)
    case noDevices
    case timeout(command: String)
    case shellFailed(code: Int32, stderr: String)
    case launchFailed(String)
}

/// A device line from `adb devices -l`.
public struct ADBDevice: Hashable, Sendable {
    public enum State: String, Sendable {
        case device, unauthorized, offline, unknown
    }
    public let serial: String
    public let state: State
    /// `model:` from the `-l` listing (underscores normalised to hyphens), if present.
    public let model: String?

    public var isReady: Bool { state == .device }
}
