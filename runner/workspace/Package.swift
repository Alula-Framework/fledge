// swift-tools-version: 6.3
// The snippet tier's prebuilt workspace (PLAN §3/§4): one dependency
// (Hangar), one executable target, built once at image-build time so
// `.build` is warm before any learner code ever runs. `Sources/exercise/
// main.swift` is the only file the runner ever overwrites — everything
// else here is fixed, which is what makes a warm rebuild ~2s instead of
// a cold one (~1.81s measured in the plan's own probe, imports Hangar +
// PostgresNIO, @Entity macros expanding).
import PackageDescription

let package = Package(
    name: "exercise-workspace",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/hangar.git", from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .executableTarget(
            name: "exercise",
            dependencies: [
                .product(name: "Hangar", package: "hangar"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
