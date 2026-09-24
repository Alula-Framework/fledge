// swift-tools-version: 6.3
import PackageDescription

// A reusable Alula module, shipped as its own package. It has no bootstrap
// list of its own — a library starts nothing — so it needs no registration
// plugin: the *application* that includes it scans it and builds it.
let package = Package(
    name: "GreetKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GreetKit", targets: ["GreetKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alula-Framework/alula.git", from: "0.36.0", traits: ["Web"])
    ],
    targets: [
        .target(
            name: "GreetKit",
            dependencies: [
                .product(name: "AlulaCore", package: "alula"),
                .product(name: "AlulaWeb", package: "alula"),
            ]
        )
    ]
)
