// swift-tools-version:5.10
// CPUMonitor — a macOS menu bar CPU / GPU / memory monitor.
// Author: Mark Castelluccio. Written with assistance from Claude (Anthropic).

import PackageDescription

let package = Package(
    name: "CPUMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "StatsCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "CPUMonitor",
            dependencies: ["StatsCore"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]
        ),
        .testTarget(
            name: "StatsCoreTests",
            dependencies: ["StatsCore"]
        ),
    ]
)
