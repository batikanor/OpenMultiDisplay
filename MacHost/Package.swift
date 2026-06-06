// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenMultiDisplay",
    platforms: [
        .macOS(.v14)  // Required for CGVirtualDisplay API
    ],
    products: [
        .executable(
            name: "OpenMultiDisplay",
            targets: ["OpenMultiDisplay"])
    ],
    targets: [
        .executableTarget(
            name: "OpenMultiDisplay",
            dependencies: [],
            path: "Sources",
            cSettings: [
                .unsafeFlags(["-I", "Sources"])
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-fmodule-map-file=Sources/module.modulemap"])
            ]),
        .testTarget(
            name: "OpenMultiDisplayTests",
            dependencies: ["OpenMultiDisplay"],
            path: "Tests/OpenMultiDisplayTests",
            cSettings: [
                .unsafeFlags(["-I", "Sources"])
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-fmodule-map-file=Sources/module.modulemap"])
            ]
        )
    ]
)
