// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuhuMacbook",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SuhuMacbook", targets: ["SuhuMacbook"])],
    targets: [
        .target(name: "CSMC", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "MonitorCore", dependencies: ["CSMC"]),
        .executableTarget(name: "SuhuMacbook", dependencies: ["MonitorCore"]),
        .testTarget(name: "MonitorCoreTests", dependencies: ["MonitorCore"])
    ]
)
