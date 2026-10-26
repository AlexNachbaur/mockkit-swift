# MockKit

[![Build](https://github.com/AlexNachbaur/mockkit-swift/actions/workflows/build.yml/badge.svg)](https://github.com/AlexNachbaur/mockkit-swift/actions/workflows/build.yml)
[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20Linux%20%7C%20Windows%20%7C%20Android-blue.svg)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

Native Swift mock servers for local UI-test automation.

MockKit runs a lightweight, stateful backend alongside your tests, so your app talks to a real
server — one you control entirely from Swift, with no folder of brittle JSON fixtures and no
network flakiness. Point it at the GraphQL schema or OpenAPI spec you already have, seed a
starting world from validated YAML/JSON, and write the endpoints that need custom behavior as
Swift closures. It was built for XCUITest, and it runs anywhere Swift does.

| Product | What it mocks | Guide |
| --- | --- | --- |
| **MockQL** | GraphQL: SDL or Swift-DSL schemas, queries, mutations, Relay connections, `graphql-transport-ws` subscriptions | [docs/MockQL.md](docs/MockQL.md) |
| **MockREST** | REST: OpenAPI 3.0/3.1 or a Swift endpoint DSL, stateful auto-CRUD, validated requests, fault injection, auth, CORS | [docs/MockREST.md](docs/MockREST.md) |
| **MockCore** | The shared platform — use it directly to mock a protocol of your own | [docs/MockCore.md](docs/MockCore.md) |

Each product has a NIO-free engine alongside it (`MockQLCore`, `MockRESTCore`,
`MockCore`) for executing requests in-process without binding a port.

## Installation

Add the package once, then link the products you need to your **UI-test target** — MockKit is
a test-time tool and does not belong in your app:

```swift
dependencies: [
    .package(url: "https://github.com/AlexNachbaur/mockkit-swift.git", from: "0.6.0")
],
targets: [
    .testTarget(name: "MyAppUITests", dependencies: [
        .product(name: "MockQL", package: "mockkit-swift"),      // GraphQL
        .product(name: "MockREST", package: "mockkit-swift"),    // REST
    ])
]
```

In Xcode: **File ▸ Add Package Dependencies…**, enter the repository URL, and link the
libraries you want to your UI testing bundle. Only the products you link are built, and every
product shares one version.

## Quick start

A GraphQL server from the schema file your app already uses:

```swift
import MockQL

let server = try await MockQLServer.start(
    schema: .file(schemaPath),
    seed: .file(seedPath)           // validated against the schema at startup
) {
    Mutation("updateDisplayName") { input, state in
        state.update("User", id: "user-1") { $0["name"] = input["name"] }
        return state["User", id: "user-1"]
    }
}

app.launchEnvironment["GRAPHQL_URL"] = server.url.absoluteString
```

A REST server from an OpenAPI spec, with one hand-written endpoint:

```swift
import MockREST

let server = try await MockRESTServer.start(
    spec: .file(specPath),          // OpenAPI 3.0/3.1, YAML or JSON
    seed: .file(seedPath)
) {
    Post("/users/{userId}/verify") { req, state in
        state.update("User", id: req.pathParam("userId")) { $0["verified"] = true }
        return .ok(state["User", id: req.pathParam("userId")])
    }
}

app.launchEnvironment["API_BASE_URL"] = server.url.absoluteString
```

Anything the seed doesn't pin down is generated deterministically, and stays stable for the
server's lifetime. Both `start` calls can be awaited from a `@MainActor` test method, such as an
XCUITest `setUp`.

## One port, both protocols

The products compose: register both engines on one `MockHost` with one shared `StateStore`, and
a mutation made over REST is immediately visible to a GraphQL query, and vice versa.

```swift
import MockQL
import MockREST

let store = StateStore()
let host = try await MockHost.start {
    try await MockRESTEngine(spec: .file(specPath), seed: .file(seedPath), store: store)
    try await MockQLEngine(schema: .file(schemaPath), store: store)
}

app.launchEnvironment["API_BASE_URL"] = host.url.absoluteString   // one URL, both protocols
```

`host.stop()` drains in-flight requests and is safe to call more than once;
`MockHost.withRunning(services:) { host in … }` stops the host on every exit path.

## Requirements

- **Swift 6.3+**, with strict concurrency.
- macOS 14+ and iOS 17+ on Apple platforms. The minimums exist only for Swift concurrency
  APIs.
- macOS, iOS, Linux, Windows and Android are all supported. CI builds and tests every
  product on all five, including the full HTTP stack.
- Dependencies: [Yams](https://github.com/jpsim/Yams) and
  [SwiftNIO](https://github.com/apple/swift-nio). The NIO-free engines need only Yams.

## Documentation

- The guides: [MockQL](docs/MockQL.md), [MockREST](docs/MockREST.md), [MockCore](docs/MockCore.md).
- [API documentation](https://swiftpackageindex.com/AlexNachbaur/mockkit-swift/documentation):
  DocC for every module, including tutorials and the XCUITest integration guides.
- Formats and design: the [MockQL seed format](docs/mockql/design/seed-format.md), the
  [REST format](docs/mockrest/design/rest-format.md), and the
  [platform architecture](docs/architecture.md).
- [CHANGELOG.md](CHANGELOG.md).

### For AI coding agents

If an AI agent is wiring MockKit into your test suite, point it at the integration guide for
your protocol: [MockQL](docs/mockql/agents/integration-guide.md) or
[MockREST](docs/mockrest/agents/integration-guide.md). Each is a self-contained document with
the canonical test patterns, known pitfalls and an error-to-fix table. They're written to be
pasted into a project's `AGENTS.md`/`CLAUDE.md` or referenced by URL, and [llms.txt](llms.txt)
indexes them. Agents contributing to MockKit itself should read [AGENTS.md](AGENTS.md).

## Contributing

Contributions are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the development setup,
where code belongs, the style rules and the pull request process. Please also read the
[Code of Conduct](CODE_OF_CONDUCT.md). Report security issues privately, as described in
[SECURITY.md](SECURITY.md).

## License

MockKit is released under the [MIT License](LICENSE).

Copyright © 2026 Alex Nachbaur.
