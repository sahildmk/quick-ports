// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortsMonitor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PortsMonitor",
            path: "PortsMonitor",
            exclude: ["Assets.xcassets", "PortsMonitor.entitlements"]
        )
    ]
)
