// swift-tools-version: 6.3
// The runner's internal control API (PLAN §4): lease/write/run/reset/
// release, plus the workspace it drives. Deliberately plain Alula (Web
// trait only) — this is a tiny, internal, server-to-runner service, not
// a public one, and it dogfoods exactly the framework the tutorial teaches.
import PackageDescription

let package = Package(
    name: "supervisor",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Alula-Framework/alula.git", from: "0.36.0", traits: ["Web"])
    ],
    targets: [
        .executableTarget(
            name: "Supervisor",
            dependencies: [
                .product(name: "AlulaCore", package: "alula"),
                .product(name: "AlulaWeb", package: "alula"),
                .product(name: "AlulaTransport", package: "alula")
            ],
            plugins: [.plugin(name: "AlulaRegistrationPlugin", package: "alula")]
        )
    ]
)
