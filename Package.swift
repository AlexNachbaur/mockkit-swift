// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MockKit",
    // Minimum Apple OS versions only — required for Swift concurrency APIs on Apple targets.
    // This does NOT limit platform support: Linux, Windows, and Android ignore this field
    // entirely. All five supported platforms — macOS, iOS, Linux, Windows, Android — build and
    // test in CI, every product on every one.
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        // GraphQL: engine + HTTP/WebSocket transport. Most GraphQL consumers want this.
        .library(name: "MockQL", targets: ["MockQL"]),
        // GraphQL engine only (no SwiftNIO) — for hosts that execute in-process.
        .library(name: "MockQLCore", targets: ["MockQLCore"]),
        // REST: engine + the MockService transport adapter. Most REST consumers want this.
        .library(name: "MockREST", targets: ["MockREST"]),
        // REST engine only (no SwiftNIO) — for hosts that execute in-process.
        .library(name: "MockRESTCore", targets: ["MockRESTCore"]),
        // The platform, for writing your own protocol extension. Portable foundation (no
        // SwiftNIO): value model, state store, generators, seed primitives, diagnostics.
        .library(name: "MockCore", targets: ["MockCore"]),
        // The shared HTTP/WebSocket listener (MockHost) and the MockService extension seam.
        .library(name: "MockCoreTransport", targets: ["MockCoreTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.70.0"),
        // Build-time only: enables `swift package generate-documentation` for the DocC catalogs.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        // MARK: MockCore — the platform

        .target(
            name: "MockCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .target(
            name: "MockCoreTransport",
            dependencies: [
                "MockCore",
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
            ]
        ),
        .testTarget(name: "MockCoreTests", dependencies: ["MockCore"]),
        .testTarget(
            name: "MockCoreTransportTests",
            dependencies: [
                "MockCoreTransport",
                // Drives the HTTP handler deterministically, without a socket, for the paths a
                // real client cannot time reliably (a request arriving mid-shutdown).
                .product(name: "NIOEmbedded", package: "swift-nio"),
            ]
        ),

        // MARK: MockQL — GraphQL

        .target(name: "MockQLCore", dependencies: ["MockCore"]),
        .target(
            name: "MockQL",
            dependencies: [
                "MockQLCore",
                "MockCoreTransport",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
            ]
        ),
        .testTarget(name: "MockQLCoreTests", dependencies: ["MockQLCore"]),
        .testTarget(name: "MockQLTests", dependencies: ["MockQL"]),
        .testTarget(
            name: "MockQLIntegrationTests",
            dependencies: ["MockQL"],
            resources: [.copy("Fixtures")]
        ),

        // MARK: MockREST — REST

        .target(name: "MockRESTCore", dependencies: ["MockCore"]),
        .target(name: "MockREST", dependencies: ["MockRESTCore", "MockCoreTransport"]),
        .testTarget(name: "MockRESTCoreTests", dependencies: ["MockRESTCore"]),
        .testTarget(
            name: "MockRESTIntegrationTests",
            // MockQL is here for the cross-protocol suite: REST + GraphQL on one MockHost.
            dependencies: ["MockREST", "MockQL"]
        ),
    ]
)
