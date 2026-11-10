// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ZelotesMac",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "ZelotesKit"),
        .executableTarget(name: "ZelotesMac", dependencies: ["ZelotesKit"]),
        .executableTarget(name: "ZelotesProbe", dependencies: ["ZelotesKit"]),
        .executableTarget(name: "ZelotesPointerAgent", dependencies: ["ZelotesKit"]),
        .testTarget(name: "ZelotesKitTests", dependencies: ["ZelotesKit"]),
    ]
)
