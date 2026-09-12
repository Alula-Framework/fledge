// swift-tools-version: 6.3
import PackageDescription

// A reusable Flight module, shipped as its own package. It has no bootstrap
// list of its own — a library starts nothing — so it needs no registration
// plugin: the *application* that includes it scans it and builds it.
let package = Package(
    name: "GreetKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GreetKit", targets: ["GreetKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/flight.git", from: "0.17.0", traits: ["Web"])
    ],
    targets: [
        .target(
            name: "GreetKit",
            dependencies: [
                .product(name: "FlightCore", package: "flight"),
                .product(name: "FlightWeb", package: "flight"),
            ]
        )
    ]
)
