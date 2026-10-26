# MockKit Architecture

How MockKit is put together: the modules, the `MockService` seam that protocol extensions plug
into, and the decisions that shape them. Where this document and the code disagree, the
sources and API documentation are authoritative.

## 1. Goal

A family of native-Swift mock servers for local UI-test automation that share one in-memory
backend, one data-generation system, and one HTTP listener. A single test process can present
one virtual server that answers REST and GraphQL (and any protocol added later) on one port,
while each protocol stays separately adoptable as its own product.

The protocol-neutral parts — transport, state store, generators, diagnostics — live in one
foundation, **MockCore**. MockQL and MockREST are built on it, and so can any other mock
extension.

### Design principles

1. **Developer experience first.** Ergonomic, expressive, result-builder-based APIs.
2. **Error messages are a product feature.** Precise source locations and document paths,
   "did you mean" suggestions, and fail-fast validation before the server accepts connections.
3. **Swift best practices.** Swift 6 strict concurrency, `Sendable` correctness, small focused
   types, doc comments on all public API, value types over reference types.
4. **Everything is unit-tested; the full stack is integration-tested** over real HTTP.
5. **Fail loud and early.** Specs, schemas and seeds are fully validated at load.
6. **MockCore is an extension platform.** REST and GraphQL are two extensions, not the whole
   design. The public seam (`MockService`) lets a third party add a new mockable protocol
   without changes to MockCore.

## 2. Package topology

One package, `mockkit-swift`, with a product per module. The consumer's test target links the
products it needs:

```
   mockkit-swift
   ┌──────────────────────────────────────────────────────────────────────────┐
   │                  ┌─────────────────────────────┐                         │
   │                  │  MockCore         (portable) │  value model, state     │
   │                  │  MockCoreTransport (NIO)     │  store, generators,     │
   │                  └──────────────┬───────────────┘  seeded RNG, seed       │
   │                                 │                  primitives, diagnostics,│
   │              ┌──────────────────┼──────────────┐   MockHost + MockService │
   │              │                  │              ... (further extensions:   │
   │     ┌────────▼────────┐ ┌───────▼─────────┐        gRPC, SOAP, WS-RPC)    │
   │     │  MockQLCore      │ │ MockRESTCore    │                              │
   │     │  MockQL          │ │ MockREST        │                              │
   │     └────────┬─────────┘ └───────┬─────────┘                              │
   └──────────────┼───────────────────┼────────────────────────────────────────┘
                  └─────────┬─────────┘
                            │  (test target links the products it needs;
                     ┌──────▼───────┐   extensions never depend on each other)
                     │  MyAppUITests │
                     └───────────────┘
```

Key property: **no extension module depends on any other extension module.** They are siblings
that only share MockCore. Composition happens in the consumer's test target, which links
whichever products it wants and registers them on one `MockHost`. (The cross-protocol
integration tests link both, but that is a test target, never shipped.)

Every product is released under one version, so a change to MockCore and the extensions that
use it lands, and ships, together.

### Module layout

**MockCore**
- `MockCore` — pure portable Swift (Yams only; **never imports NIO**):
  - `MockValue` — the protocol-neutral dynamic value type (see §4).
  - `StateStore` / `MutationState` / `StoreData` — the in-memory backend.
  - `FieldGenerator`, `GeneratorContext`, `GeneratorRegistry`, built-in presets.
  - `RandomSource` — seeded deterministic RNG.
  - Seed primitives shared by extensions (value decoding from YAML/JSON, reference model).
  - Diagnostics: `SourceLocation`, `Suggestion`, and `MockError`, carrying category, location
    and suggestions.
- `MockCoreTransport` — the SwiftNIO transport:
  - `MockHost` — the HTTP and WebSocket listener; binds a port, owns the NIO event loop group,
    and dispatches each request to the first `MockService` that claims it.
  - `MockService` — the extension seam (see §3).
  - `MockRequest` / `MockResponse` — the neutral request/response the host hands to services.

**MockQL** — `MockQLCore` (the engine) and `MockQL` (the transport). `MockQLEngine` conforms to
`MockService`.

**MockREST** — `MockRESTCore` (the engine) and `MockREST` (the transport). `MockRESTEngine`
conforms to `MockService`.

## 3. The extension seam: `MockService`

The whole platform hinges on one protocol. A mock extension is anything that can (a) say
whether it wants to handle an incoming request and (b) produce a response, sharing the MockCore
state store and generators.

```swift
public protocol MockService: Sendable {
    /// Human-readable name for diagnostics and startup logging (e.g. "MockREST").
    var name: String { get }

    /// Whether this service claims the request. The host asks registered services in
    /// registration order and routes to the first that returns `true`.
    func claims(_ request: MockRequest) -> Bool

    /// Produces the response for a claimed request.
    func respond(to request: MockRequest) async -> MockResponse

    /// How to handle a WebSocket upgrade, or `nil` (the default). GraphQL uses it for
    /// `graphql-transport-ws` subscriptions; REST does not.
    func webSocketUpgrade(for request: MockRequest) -> MockWebSocketUpgrade?

    /// Called once, in registration order, before the host accepts connections: fail-fast
    /// validation goes here (or earlier, at construction). Defaults to a no-op.
    func willStart() async throws

    /// Called on host shutdown to release resources and end streams. Defaults to a no-op.
    func shutdown() async
}
```

- **Routing.** `MockHost` holds an ordered list of services. For each request it calls
  `claims(_:)` in order and dispatches to the first that returns `true`; if none claims it, the
  host returns a 404 with a diagnostic listing the registered services. GraphQL claims
  `/graphql`; REST claims the routes its spec and DSL define. Registration order is the user's
  precedence lever — documented, not magic.
- **Shared state.** Each engine takes an optional `store:`. Give several services the same
  `StateStore` and a mutation performed through REST is visible to the next GraphQL query, and
  vice versa; leave it out and the service keeps a store of its own.
- **One port.** The host owns the socket; services never bind their own. That is what makes
  the single virtual server real.
- **WebSocket upgrades** are part of the seam rather than a GraphQL special case in
  `MockHost`: the optional requirement defaults to `nil`, and REST ignores it.

### Composition entry point

```swift
let store = StateStore()
let host = try await MockHost.start {               // binds an ephemeral port by default
    try await MockRESTEngine(spec: .file("api.yaml"), seed: .file("world.yaml"), store: store)
    try await MockQLEngine(schema: .file("shop.graphqls"), store: store)
}
app.launchEnvironment["API_BASE_URL"] = host.url.absoluteString   // one URL, both protocols
```

`MockHost.start` takes a result builder of `MockService`s; `if`, `switch` and `for` work inside
it. Each extension also has its own standalone `start` (`MockQLServer.start(...)`,
`MockRESTServer.start(...)`) that wraps a single-service `MockHost`, so adopting one extension
stays a one-liner. `MockHost.withRunning(services:) { host in … }` scopes a host to a block and
stops it on every exit path.

## 4. The neutral value model

`MockValue` is the dynamic value tree every extension speaks — seeds, arguments, records,
responses. Its cases are `null`, `bool`, `int`, `double`, `string`, `enumValue`, `list`,
`object` and `reference(type, id)`, with literal conformances, subscripts, `append`, `??`, and
`CustomStringConvertible`. `enumValue` is not GraphQL-specific: OpenAPI schemas have enums too.
MockQL spells it `GraphQLValue` (a typealias); MockREST uses `MockValue` directly.

`reference(type, id:)` is in the neutral model because it is a store concept ("this field points
at record X"), not a GraphQL one. Schema-driven reference *resolution* — what a bare string in a
typed position means — lives in each extension, since it depends on that extension's schema.

## 5. State, generators, seeding (shared)

- `StateStore` (an actor) and `MutationState` (transactional writes committed atomically) speak
  only `MockValue` and `type`/`id` strings.
- `FieldGenerator`, `GeneratorContext` and `RandomSource` are keyed by `"Type.field"`. Each
  extension supplies the "Type" namespace: the GraphQL type name, or the REST schema or
  resource name.
- **Seed primitives** are shared: YAML/JSON → `MockValue` decoding, duplicate-id detection, the
  reference-string model, generator fill-in of omitted fields with lifetime-stable values, and
  `null`-pinning. **Schema-specific validation** (does this field exist on this type? is this
  enum member valid?) stays in each extension, driven by its own schema model. The formats are
  specified in [mockql/design/seed-format.md](mockql/design/seed-format.md) and
  [mockrest/design/rest-format.md](mockrest/design/rest-format.md).

## 6. Dependencies, platforms, licensing

- **Toolchain:** Swift 6.3, strict concurrency. `Package.swift` declares Apple minimums
  (macOS 14 / iOS 17) only for concurrency availability; Linux, Windows and Android are
  unaffected. CI covers macOS, an iOS simulator, Linux, Windows, and an Android emulator.
- **Dependencies:** Yams (YAML) in `MockCore`; SwiftNIO in the transport modules. The engines
  are NIO-free, which buys in-process execution rather than portability — SwiftNIO builds and
  runs on every platform MockKit targets, Windows included. MockREST's OpenAPI ingestion is
  hand-rolled Codable and validation, with no extra dependency. No other dependencies without
  asking.
- **License:** MIT.
- **swift-format** enforced (120 columns, 4-space indent), no force unwraps, no `DispatchQueue`.

## 7. Settled decisions

1. **`MockCoreTransport` is a separate module**, so `MockCore` stays NIO-free.
2. **`claims(_:)` returns `Bool`**, first match wins in registration order — documented and
   deterministic. Revisit only if real conflicts between services appear.
3. **State is shared by passing one `StateStore`** to the services that should share it; a
   service given none keeps its own.
4. **The WebSocket upgrade hook is part of the seam**: an optional `MockService` requirement
   with a default `nil` implementation, so `MockHost` has no GraphQL special-casing.
