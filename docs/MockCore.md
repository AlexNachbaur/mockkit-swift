# MockCore

The shared foundation of [MockKit](../README.md)'s mock servers, and the seam for writing your
own.

MockCore exists so that a single test process can present **one virtual server** — one port,
one in-memory world — that answers multiple protocols at once. The protocol extensions plug
into it, and each is a separate product of the MockKit package:

| Extension | Protocol |
|---|---|
| [MockQL](MockQL.md) | GraphQL (queries, mutations, `graphql-transport-ws` subscriptions) |
| [MockREST](MockREST.md) | REST / OpenAPI 3.0–3.1 |

Most apps depend on one of those; depend on MockCore directly to build a new protocol
extension. The `MockService` seam is validated by both shipping extensions.

## One host, many protocols

Each extension works standalone, but the platform's headline feature is composition: register
several services on one `MockHost` and hand them one shared `StateStore`. A mutation performed
through REST is instantly visible to a GraphQL query, and vice versa — because there is only
one world.

```swift
import MockQL
import MockREST

let store = StateStore()
let host = try await MockHost.start {
    try await MockRESTEngine(spec: .file("api.yaml"), seed: .file("world.yaml"), store: store)
    try await MockQLEngine(schema: .file("shop.graphqls"), store: store)
}

app.launchEnvironment["API_BASE_URL"] = host.url.absoluteString   // one URL, both protocols
```

The host asks registered services `claims(_:)` in registration order and routes each request to
the first match; unclaimed requests get a diagnostic 404 that names the registered services.

The block is an ordinary result builder — `if`, `switch`, and `for` work — and it runs on the
caller's actor, so it can be written inside a `@MainActor` test class. `host.stop()` closes the
listener, lets in-flight requests finish, then shuts the services down; it is safe to call
more than once. When a host lives for a single scope, `MockHost.withRunning(services:) { host
in … }` stops it on every exit path, including a thrown test failure.

## Modules

- **`MockCore`** — pure portable Swift (no networking):
  - `MockValue` — the dynamic value tree every extension speaks (seeds, arguments, records,
    responses), with literal conformances, subscripts, and JSON/YAML codecs.
  - `StateStore` / `MutationState` — an actor-guarded in-memory backend with transactional,
    atomically-committed writes; shareable across services.
  - `FieldGenerator` / `GeneratorRegistry` / `RandomSource` — deterministic data generation
    (names, emails, phone numbers, UUIDs, timestamps, …), stable per record + field and
    reproducible from a server seed.
  - `SeedSource` + YAML/JSON decoding — seed-document primitives (schema validation belongs to
    each extension).
  - `MockError` / `SourceLocation` / `Suggestion` — diagnostics with locations, document paths,
    and "did you mean" suggestions.
- **`MockCoreTransport`** — the SwiftNIO listener:
  - `MockHost` — binds a loopback port, runs every service's fail-fast `willStart()` before
    accepting connections, routes requests, answers `GET /health`.
  - `MockService` — the extension seam: `claims(_:)`, `respond(to:)`, and optional hooks for
    WebSocket upgrades, startup validation, and shutdown.
  - `MockRequest` / `MockResponse` — the neutral request/response pair.

## Writing your own extension

A mock extension is any `Sendable` type that can say whether it wants a request and produce a
response. That's the whole seam — MockCore needs no changes to host a new protocol:

```swift
import MockCore
import MockCoreTransport

struct StatusService: MockService {
    let name = "Status"
    let store: StateStore

    func claims(_ request: MockRequest) -> Bool {
        request.path == "/status"
    }

    func respond(to request: MockRequest) async -> MockResponse {
        let count = await store.records(ofType: "User").count
        return (try? .json(["users": .int(count)])) ?? MockResponse(status: 500)
    }
}
```

Conventions the shipping extensions follow (and yours should too):

- **Validate everything at startup** (specs, seeds, configuration) in your initializer or
  `willStart()` — never mid-test. Use `MockError` with paths and `Suggestion` for typos.
- **Speak `MockValue`** for state, and store records as `(type, id)` pairs so cross-protocol
  reference resolution works.
- **Key generators as `"Type.field"`**, where `Type` is your schema's namespace.

## Installation

Depend on MockCore directly only when building a new extension; otherwise one of the
protocol products brings it in:

```swift
dependencies: [
    .package(url: "https://github.com/AlexNachbaur/mockkit-swift.git", from: "0.6.0")
],
targets: [
    .target(name: "MyMockExtension", dependencies: [
        .product(name: "MockCore", package: "mockkit-swift"),
        .product(name: "MockCoreTransport", package: "mockkit-swift"),
    ])
]
```

## Requirements

- **Swift 6.3+** (strict concurrency).
- Apple platforms: macOS 14+ / iOS 17+ (minimums exist only for Swift concurrency APIs).
- macOS, iOS, Linux, Windows, and Android are all supported, and CI builds and tests both
  products on every one of them.
- `MockCore` itself has no networking dependency, so it is also usable in-process on any host
  that cannot or does not want to run a listener.
- Dependencies: [Yams](https://github.com/jpsim/Yams) (`MockCore`),
  [SwiftNIO](https://github.com/apple/swift-nio) (`MockCoreTransport`).

## Documentation

- [API documentation](https://swiftpackageindex.com/AlexNachbaur/mockkit-swift/documentation/mockcore)
  (DocC) — the value model, state store, generators, and the hosting/extension seam.
- [architecture.md](architecture.md) — the platform design: module topology, the
  `MockService` seam, settled decisions. The history of how the platform was split out of
  MockQL is in [mockrest/design/extraction-plan.md](mockrest/design/extraction-plan.md).

Contributing, security reports and the license are covered in MockKit's
[README](../README.md#contributing).
