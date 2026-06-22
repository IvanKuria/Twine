// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwineKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TwineKit", targets: ["TwineKit"])],
    targets: [
        .target(
            name: "TwineKit",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "TwineKitTests", dependencies: ["TwineKit"]),
    ]
)
