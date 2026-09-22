// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Attune",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "attune", targets: ["attune"]),
        .library(name: "AttuneCore", targets: ["AttuneCore"]),
    ],
    targets: [
        .target(
            name: "AttuneCore",
            path: "Sources/AttuneCore"
        ),
        .executableTarget(
            name: "attune",
            dependencies: ["AttuneCore"],
            path: "Sources/attune"
        ),
        .testTarget(
            name: "AttuneCoreTests",
            dependencies: ["AttuneCore"],
            path: "Tests/AttuneCoreTests"
        ),
    ]
)
