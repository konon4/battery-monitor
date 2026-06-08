// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryMonitor",
    platforms: [.macOS(.v14)],   // SwiftData + MenuBarExtra + Swift Charts
    products: [
        .library(name: "BatteryCore", targets: ["BatteryCore"]),
        // Dev/headless runner for the GUI app (the shippable .app is built from the
        // Xcode target via project.yml — kept a distinct name to avoid a scheme clash).
        .executable(name: "battery-monitor", targets: ["BatteryMonitorCLI"]),
        .executable(name: "bmprobe", targets: ["bmprobe"]),
    ],
    targets: [
        .target(
            name: "BatteryCore",
            path: "Sources/BatteryCore"
        ),
        .executableTarget(
            name: "BatteryMonitorCLI",
            dependencies: ["BatteryCore"],
            path: "App"
        ),
        .executableTarget(
            name: "bmprobe",
            dependencies: ["BatteryCore"],
            path: "Sources/bmprobe"
        ),
        .testTarget(
            name: "BatteryCoreTests",
            dependencies: ["BatteryCore"],
            path: "Tests/BatteryCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
