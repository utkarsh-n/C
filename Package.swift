// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "C",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [.library(name: "CCore", targets: ["CCore"])],
    targets: [
        .target(name: "CCore"),
        .testTarget(name: "CCoreTests", dependencies: ["CCore"])
    ]
)
