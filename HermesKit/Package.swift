// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "HermesKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HermesKit", targets: ["HermesKit"]),
    ],
    targets: [
        .target(name: "HermesKit"),
        .testTarget(name: "HermesKitTests", dependencies: ["HermesKit"]),
    ]
)
