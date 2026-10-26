# Changelog

All notable changes to MockKit will be documented in this file. Every product is released
together, so one version covers them all; entries name the product they affect.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While MockKit is
pre-1.0, a minor release may break the public API; each break is called out here.

## [Unreleased]

## [0.6.0] - 2026-10-25

The first release of MockKit: native Swift mock servers for UI-test automation, as one package
with six library products.

### Added

- **MockQL** (`MockQL`, `MockQLCore`) — a stateful GraphQL server. Schemas from SDL or a Swift
  result-builder DSL; validated YAML/JSON seeds; mutations as Swift closures over transactional
  state; Relay connections with forward and backward pagination; `graphql-transport-ws`
  subscriptions, with queries and mutations over the same socket.
- **MockREST** (`MockREST`, `MockRESTCore`) — a stateful REST server. OpenAPI 3.0/3.1 specs
  and/or a Swift endpoint DSL; auto-CRUD with filtering, sorting and pagination; request
  validation (bodies, required query and header parameters); fault injection, latency, bearer
  auth simulation and CORS.
- **MockCore** (`MockCore`, `MockCoreTransport`) — the shared platform: the `MockValue` model,
  a transactional `StateStore`, deterministic generators, seed primitives, diagnostics with
  document paths and "did you mean" suggestions, and `MockHost`, which serves any number of
  `MockService`s on one port. GraphQL and REST registered on one host with one store see the
  same data.
- Every product builds and is tested on macOS, iOS, Linux, Windows and Android. The `…Core`
  engines are NIO-free, for in-process execution without a listener.

[Unreleased]: https://github.com/AlexNachbaur/mockkit-swift/compare/0.6.0...HEAD
[0.6.0]: https://github.com/AlexNachbaur/mockkit-swift/releases/tag/0.6.0
