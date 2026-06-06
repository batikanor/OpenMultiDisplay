// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TetherSpan",
    platforms: [
        .macOS(.v14)  // Required for CGVirtualDisplay API
    ],
    products: [
        .executable(
            name: "TetherSpan",
            targets: ["TetherSpan"])
    ],
    targets: [
        .executableTarget(
            name: "TetherSpan",
            dependencies: [],
            path: "Sources",
            cSettings: [
                .unsafeFlags(["-I", "Sources"])
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-fmodule-map-file=Sources/module.modulemap"])
            ]),
        .testTarget(
            name: "TetherSpanTests",
            dependencies: ["TetherSpan"],
            path: "Tests/TetherSpanTests",
            cSettings: [
                .unsafeFlags(["-I", "Sources"])
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-fmodule-map-file=Sources/module.modulemap"])
            ]
        )
    ]
)
