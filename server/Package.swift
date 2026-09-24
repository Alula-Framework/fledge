// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "server",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Alula-Framework/alula.git", from: "0.36.0", traits: ["Web"]),
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
                .product(name: "AlulaCore", package: "alula"),
                .product(name: "AlulaWeb", package: "alula"),
                .product(name: "AlulaTransport", package: "alula"),
                .product(name: "AlulaChannels", package: "alula"),
                .product(name: "AlulaPubSub", package: "alula"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "PostgresNIO", package: "postgres-nio")
            ],
            plugins: [.plugin(name: "AlulaRegistrationPlugin", package: "alula")]
        )
    ]
)
