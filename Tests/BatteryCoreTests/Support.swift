import Foundation
import XCTest
@testable import BatteryCore

/// Replays canned shell output for tests, keyed by a substring of the command.
/// Longest matching needle wins, so `"dumpsys batterystats"` is distinguished from the
/// `"dumpsys battery"` substring it contains.
struct FakeShellRunner: ShellRunner {
    let responses: [String: String]   // command-substring -> output
    func shell(serial: String, _ command: String) async throws -> String {
        responses
            .filter { command.contains($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value ?? ""
    }
}

enum Fixture {
    static func text(_ name: String, ext: String) throws -> String {
        // Resources are copied preserving the Fixtures/ subdirectory.
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: ext)
        let unwrapped = try XCTUnwrap(url, "fixture \(name).\(ext) not found in test bundle")
        return try String(contentsOf: unwrapped, encoding: .utf8)
    }
}

let utcCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: y, month: m, day: d))!
}
