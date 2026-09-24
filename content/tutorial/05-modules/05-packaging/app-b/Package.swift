// swift-tools-version: 6.3
import PackageDescription

// This application installs one reusable module, GreetKit, from a package
// alongside it. In a real project GreetKit would be a URL dependency like
// `alula` itself; here it is a sibling directory so the two travel together.
let package = Package(
    name: "App",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alula-Framework/alula.git", from: "0.36.0", traits: ["Web"]),
        .package(path: "GreetKit"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "AlulaCore", package: "alula"),
                .product(name: "AlulaWeb", package: "alula"),
                .product(name: "AlulaTransport", package: "alula"),
                .product(name: "AlulaActuator", package: "alula"),
                // The reusable module's product. Adding this, and naming the
                // module in Main's `modules:` list, is the entire install.
                .product(name: "GreetKit", package: "GreetKit"),
            ],
            plugins: [
                .plugin(name: "AlulaRegistrationPlugin", package: "alula")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                .product(name: "AlulaCore", package: "alula"),
                .product(name: "AlulaWeb", package: "alula"),
                .product(name: "AlulaWebTesting", package: "alula"),
            ]
        ),
    ]
)
