// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "KeepAwake",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "KeepAwakeCore",
            path: "src",
            exclude: ["main.swift"]
        ),
        .testTarget(
            name: "KeepAwakeTests",
            dependencies: ["KeepAwakeCore"],
            path: "tests"
        )
    ]
)
