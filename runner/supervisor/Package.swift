// swift-tools-version: 6.3
// The runner's internal control API (PLAN §4): lease/write/run/reset/
// release, plus the workspace it drives. Deliberately plain Flight (Web
// trait only) — this is a tiny, internal, server-to-runner service, not
// a public one, and it dogfoods exactly the framework the tutorial teaches.
import PackageDescription

let package = Package(
    name: "supervisor",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/flight.git", from: "0.17.0", traits: ["Web"])
    ],
    targets: [
        .executableTarget(
            name: "Supervisor",
            dependencies: [
                .product(name: "FlightCore", package: "flight"),
                .product(name: "FlightWeb", package: "flight"),
                .product(name: "FlightTransport", package: "flight")
            ],
            plugins: [.plugin(name: "FlightRegistrationPlugin", package: "flight")]
        )
    ]
)
