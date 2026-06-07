import Foundation

/// Finds the `adb` executable. Order: explicit user override → common Homebrew/SDK
/// locations → `$PATH`. Returns nil if adb cannot be found (app then guides install).
public enum AdbLocator {
    public static let commonPaths = [
        "/opt/homebrew/bin/adb",                                  // Apple-silicon Homebrew
        "/usr/local/bin/adb",                                     // Intel Homebrew
        "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb", // Android Studio SDK
    ]

    public static func discover(customPath: String? = nil) -> String? {
        if let customPath, isExecutable(customPath) { return customPath }
        for path in commonPaths where isExecutable(path) { return path }
        return searchPATH()
    }

    static func isExecutable(_ path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue && fm.isExecutableFile(atPath: path)
    }

    static func searchPATH() -> String? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.split(separator: ":") {
            let candidate = "\(dir)/adb"
            if isExecutable(candidate) { return candidate }
        }
        return nil
    }
}
