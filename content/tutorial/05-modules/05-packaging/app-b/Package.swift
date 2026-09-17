// swift-tools-version: 6.3
import PackageDescription

// This application installs one reusable module, GreetKit, from a package
// alongside it. In a real project GreetKit would be a URL dependency like
// `flight` itself; here it is a sibling directory so the two travel together.
let package = Package(
    name: "App",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/flight.git", from: "0.18.0", traits: ["Web"]),
        .package(path: "GreetKit"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "FlightCore", package: "flight"),
                .product(name: "FlightWeb", package: "flight"),
                .product(name: "FlightTransport", package: "flight"),
                .product(name: "FlightActuator", package: "flight"),
                // The reusable module's product. Adding this, and naming the
                // module in Main's `modules:` list, is the entire install.
                .product(name: "GreetKit", package: "GreetKit"),
            ],
            plugins: [
                .plugin(name: "FlightRegistrationPlugin", package: "flight")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                .product(name: "FlightCore", package: "flight"),
                .product(name: "FlightWeb", package: "flight"),
                .product(name: "FlightWebTesting", package: "flight"),
            ]
        ),
    ]
)
