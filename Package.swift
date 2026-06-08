// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BatteryMonitor",
    platforms: [.macOS(.v14)],   // SwiftData + MenuBarExtra + Swift Charts
    products: [
        .library(name: "BatteryCore", targets: ["BatteryCore"]),
        .executable(name: "BatteryMonitor", targets: ["BatteryMonitor"]),
        .executable(name: "bmprobe", targets: ["bmprobe"]),
    ],
    targets: [
        .target(
            name: "BatteryCore",
            path: "Sources/BatteryCore"
        ),
        .executableTarget(
            name: "BatteryMonitor",
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
