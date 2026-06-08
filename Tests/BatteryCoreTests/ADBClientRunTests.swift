import XCTest
@testable import BatteryCore

/// Exercises the real Process execution path. Guards the fast-exit race: a quickly
/// terminating process must not hang `run()` (it previously did, because the termination
/// handler was attached after launch).
final class ADBClientRunTests: XCTestCase {
    func testRunReturnsForFastExitingProcess() async throws {
        let client = ADBClient(adbPath: "/bin/echo")
        let out = try await client.run(["hello world"])
        XCTAssertEqual(out, "hello world\n")
    }

    func testRunCapturesLargeOutputWithoutDeadlock() async throws {
        // ~600KB on stdout — exceeds the 64KB pipe buffer; concurrent draining must keep
        // the child from blocking. `seq` prints and exits on its own.
        let client = ADBClient(adbPath: "/usr/bin/seq")
        let out = try await client.run(["100000"])
        XCTAssertGreaterThan(out.count, 500_000)
        XCTAssertTrue(out.hasPrefix("1\n"))
    }

    func testTimeoutTerminatesLongProcess() async throws {
        let client = ADBClient(adbPath: "/bin/sleep", defaultTimeout: 0.3)
        do {
            _ = try await client.run(["5"])
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error as? ADBError, .timeout(command: "5"))
        }
    }
}
