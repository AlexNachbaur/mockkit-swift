# AGENTS.md

Instructions for AI coding agents working **in this repository**. If you are integrating MockKit
into another project's tests, read the integration guide for the protocol you need instead:
[MockQL](docs/mockql/agents/integration-guide.md) (GraphQL) or
[MockREST](docs/mockrest/agents/integration-guide.md) (REST).

## What this package is

MockKit is a family of native-Swift mock servers for local UI-test automation (XCUITest first;
the engines run anywhere Swift does). One Swift package, versioned and released as a whole,
with three layers:

| Layer | Products | What it is |
| --- | --- | --- |
| Platform | `MockCore`, `MockCoreTransport` | The protocol-neutral foundation: value model, transactional `StateStore`, deterministic generators, seed primitives, diagnostics, and the SwiftNIO `MockHost` with its `MockService` seam |
| GraphQL | `MockQLCore`, `MockQL` | SDL or Swift-DSL schemas, validated seeds, closures over state, HTTP plus `graphql-transport-ws` subscriptions |
| REST | `MockRESTCore`, `MockREST` | OpenAPI 3.0/3.1 specs or a Swift DSL, resource CRUD, validated requests, JSON responses |

Each `…Core` module is the portable engine; the module without the suffix adds the transport.
One `MockHost` serves any number of services on one port, sharing one `StateStore`.

## Making decisions

- **Never assume or default to the easiest solution.** When there is a real choice — an
  architectural direction, a public-API shape, a behavior an existing test deliberately
  asserts — stop and ask first.
- Present the options with trade-offs and a recommendation; the maintainer has the final say.
- Do not silently pick an approach, even when one seems obvious.
- Decisions already recorded below are settled: build on them rather than re-asking.

## Build, test, lint

```sh
make check    # lint, build, test, docs — everything below, in the order CI gates them
```

`make check` must pass before any commit. It runs:

```sh
swift format lint --strict --recursive Sources Tests Package.swift
swift build
swift test
swift package generate-documentation --target MockCore --target MockCoreTransport \
  --target MockQLCore --target MockQL --target MockRESTCore --target MockREST --warnings-as-errors
```

`make format` applies the formatter. The documentation build is deliberately a **local** step:
CI does not run it, so a DocC regression will only ever be caught here. While iterating,
`swift test --filter MockQLCoreTests` (or any test target) keeps the loop short; `make check`
runs everything.

CI builds and tests on macOS, an iOS simulator, Linux (`swift:6.3` container), Windows, and an
Android emulator, and must pass on all five. Do not introduce Apple-only framework imports in
library targets, and stick to Foundation APIs that swift-corelibs-foundation also provides.

## Design principles

1. **Developer experience comes first.** APIs must be ergonomic and expressive and support the
   consumer's situation: a schema file or a Swift DSL; file, inline, or builder seeds; HTTP
   transport or in-process execution.
2. **Diagnostics are a product feature.** Every user-facing error is a `MockError` with a source
   name/location or document path (`paths./users/{id}.get.responses.200`,
   `data.User[0].email`) and actionable guidance, including `Suggestion` "did you mean" clauses
   for plausible typos. Never regress an error message.
3. **Everything requires unit tests.** Design for testability: inject randomness (seeded RNG),
   ports (bind ephemeral, expose the resolved URL), and file access. No untested public API.
4. **Integration tests validate the full stack**: real HTTP/WebSocket round trips against a
   running server, not only unit-level coverage.
5. **Fail loud and early.** Seeds, schemas and specs are fully validated before the server
   starts. Silent leniency in test infrastructure is a bug factory.

## Architecture (settled decisions — do not relitigate)

### The package

- **One package, one version.** Every product is released together under one tag and one
  `CHANGELOG.md`, and `MockKitVersion.current` (in MockCore, re-exported everywhere) is the one
  version constant.
- **Toolchain/platforms**: Swift 6.3 (`swift-tools-version: 6.3`). `Package.swift` declares
  Apple minimums (macOS 14 / iOS 17) solely for concurrency availability; that does not limit
  Linux/Windows/Android support.
- **Dependencies are fixed**: Yams (`MockCore` only), SwiftNIO (the `NIOCore`, `NIOPosix`,
  `NIOHTTP1`, `NIOWebSocket`, and `NIOConcurrencyHelpers` products, in transport modules only;
  `NIOEmbedded` in tests), and swift-docc-plugin (build-time). Adding any other dependency
  requires asking the maintainer first.
- **The engine/transport split holds in every layer**: `MockCore`, `MockQLCore` and
  `MockRESTCore` **never import NIO**; only `MockCoreTransport`, `MockQL` and `MockREST` do.

### MockCore — the platform

- **Protocol-neutrality is the admission test**: nothing in `MockCore` or `MockCoreTransport`
  may know about GraphQL SDL, OpenAPI, or any other schema language. Schema-specific
  validation lives in the protocol modules. Machinery that would benefit every protocol (the
  value model, state store, generators, seed primitives, diagnostics, `MockHost`) belongs here,
  not duplicated in a protocol module.
- Routing is `claims(_:) -> Bool`, first match in registration order. One shared `StateStore`
  across services is the default composition model (`StateStore.merge` exists for a second
  service's seed).
- `MockQLCore` re-exports `MockCore` (`GraphQLValue` is `MockValue`, `MockQLError` is
  `MockError`) and `MockRESTCore` does too, so MockCore's public API is part of both. Renaming
  or removing a public MockCore symbol is a breaking change to every product.

### MockQL — GraphQL

- `MockQLCore`: lexer and parsers, schema model, result-builder DSL, seed loading/validation,
  input coercion, and the executor. `MockQL`: the `MockService` conformance (HTTP
  `POST /graphql` plus `graphql-transport-ws` WebSocket subscriptions) and the `MockQLServer`
  facade; re-exports `MockQLCore`.
- **The GraphQL SDL/operation parser is hand-written** on purpose: diagnostic quality and
  portability.
- **Subscriptions** speak `graphql-transport-ws` (what Apollo, urql, and Relay speak).
- **Seed format v1** — full specification in
  [docs/mockql/design/seed-format.md](docs/mockql/design/seed-format.md):
  - Top-level sections: `version: 1`, `data:` (records grouped by GraphQL object type name),
    `roots:` (wires root `Query` fields to stored records).
  - Schema-driven references: a string in an object-typed field position is a reference to a
    record's `id`; scalar-typed fields are always literal. `Type:id` qualified references are
    accepted anywhere and **required** for interface/union-typed positions.
  - Inline nested objects are anonymous embedded records (value types).
  - Omitted fields are filled by generators and stay **stable** for the server's lifetime;
    `field: null` pins an explicit null (valid only for nullable fields).
  - Coercion follows the GraphQL spec (numerics coerce to `ID` strings; enums validated;
    custom scalars pass through).
  - Relay connection synthesis: id lists auto-wrap into `edges/node/cursor/pageInfo` when the
    schema field is a Connection type, honoring `first`/`after`.
  - Validation is fail-fast at load with file/line diagnostics: unknown type or field (with
    suggestions), dangling references, duplicate ids, enum mismatches, non-coercible scalars.

### MockREST — REST

- `MockRESTCore`: spec loading, routing, validation, resources and response synthesis.
  `MockREST`: the `MockService` conformance and the `MockRESTServer` facade over
  `MockCoreTransport`.
- Settled v1 decisions (documented in
  [docs/mockrest/design/rest-format.md](docs/mockrest/design/rest-format.md) §9): OpenAPI
  3.0/3.1 only, internal `$ref`s only, `resources:` block with `idField` (default `"id"`),
  schema `example`s seed only when no explicit data, `limit`/`offset` pagination with envelope
  synthesis, `?field=` filters and `?sort=` sorting, PUT replaces only (404 when absent),
  body-validation failures are 422 with field paths, JSON-only (406 otherwise).

Platform architecture: [docs/architecture.md](docs/architecture.md). MockQL internals:
[docs/mockql/design/architecture.md](docs/mockql/design/architecture.md).

## Code style (enforced)

- swift-format with the checked-in `.swift-format`: 120 columns, 4-space indent.
- Swift 6 language mode with strict concurrency; `Sendable` correctness is not optional.
- No force unwraps anywhere (tests use `try #require(...)`); no `DispatchQueue` — Swift
  concurrency only; prefer value types and small focused types.
- Never use caseless enums as namespaces; use a struct with static members (or, for a
  genuinely shared resource, a `final class` with `static let shared`).
- Swift Testing (`import Testing`) for all tests, never XCTest.
- Every public symbol gets a doc comment; DocC must build with zero warnings.

## Testing rules

- Everything requires unit tests, next to the module they cover: `Tests/MockCoreTests`,
  `Tests/MockQLCoreTests`, `Tests/MockQLTests`, `Tests/MockRESTCoreTests` (REST unit tests are
  driven through `MockRESTEngine.execute` in-process).
- Transport behavior is tested over real HTTP with stub services in
  `Tests/MockCoreTransportTests`. Full-stack behavior belongs in `Tests/MockQLIntegrationTests`
  (against the fixtures in its `Fixtures/`) and `Tests/MockRESTIntegrationTests`, which also
  holds the cross-protocol suite proving REST and GraphQL share one `MockHost` and one
  `StateStore` — keep that suite passing in both directions.
- Scope a host to the test with `MockHost.withRunning(services:) { host in … }` so it stops
  even when an expectation throws; otherwise stop it explicitly (`try await host.stop()`, which
  is idempotent). Never stop from a detached `Task` in `defer` — that races process teardown.
- URLSession WebSocket tests must be gated `#if canImport(Darwin)` — the libcurl-backed
  URLSession on other platforms has no WebSocket support.
- Update `CHANGELOG.md` (Unreleased section, under the product it affects) for user-visible
  changes, and say *why*.
- `MockKitVersion.current` must equal the newest released heading in `CHANGELOG.md` (a test
  enforces it): bump both in the release commit, and leave a fresh `## [Unreleased]` heading.

## Important files

- `docs/architecture.md` — the platform: module topology, the `MockService` seam, settled
  design decisions.
- `docs/mockql/design/`, `docs/mockrest/design/` — each protocol's design notes and its
  seed/spec format.
- `docs/mockql/agents/integration-guide.md`, `docs/mockrest/agents/integration-guide.md` — the
  guides for agents *using* MockKit; keep their API examples compiling when the public API
  changes.
- `docs/MockCore.md`, `docs/MockQL.md`, `docs/MockREST.md` — the long-form guides the README
  links to.
- `.github/workflows/build.yml` — CI (lint gate, then Linux, then macOS/iOS/Windows/Android).
- `Makefile` — `make check`, the single pre-commit entry point.
