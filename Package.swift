// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StayAwake",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StayAwake", targets: ["StayAwake"])],
    targets: [
        .target(name: "AwakeCore"),
        .target(name: "AwakeUI", dependencies: ["AwakeCore"]),
        .executableTarget(name: "StayAwake", dependencies: ["AwakeCore", "AwakeUI"]),
        .executableTarget(name: "AwakeChecks", dependencies: ["AwakeCore"], path: "Tests/AwakeCoreTests"),
        .executableTarget(name: "PanelChecks", dependencies: ["AwakeUI"], path: "Tests/AwakeUITests")
    ]
)
