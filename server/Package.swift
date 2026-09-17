// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "server",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/flight.git", from: "0.18.0", traits: ["Web"]),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
        // Session-database provisioning (PLAN §3's `db` tier) needs a raw
        // CREATE/DROP DATABASE connection — not Hangar's query builder,
        // just the same underlying driver Hangar itself sits on. Pinned to
        // the same major version the runner's Hangar dependency resolves.
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0")
    ],
    targets: [
        .executableTarget(
            name: "Server",
            dependencies: [
                .product(name: "FlightCore", package: "flight"),
                .product(name: "FlightWeb", package: "flight"),
                .product(name: "FlightTransport", package: "flight"),
                .product(name: "FlightChannels", package: "flight"),
                .product(name: "FlightPubSub", package: "flight"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "PostgresNIO", package: "postgres-nio")
            ],
            plugins: [.plugin(name: "FlightRegistrationPlugin", package: "flight")]
        )
    ]
)
