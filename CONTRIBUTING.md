# Contributing to MockKit

Thanks for your interest in contributing! This guide is short — when in doubt, open an issue
and ask.

## Where things live

MockKit is one Swift package with three layers, each an engine module plus a transport module:

| Layer | Modules | Holds |
| --- | --- | --- |
| Platform | `MockCore`, `MockCoreTransport` | The protocol-neutral foundation: the `MockValue` model, the `StateStore`, data generators, seed primitives, diagnostics, and the `MockHost`/`MockService` transport seam |
| GraphQL | `MockQLCore`, `MockQL` | Everything GraphQL: the SDL/operation parser, schema DSL, seeds, executor, subscriptions |
| REST | `MockRESTCore`, `MockREST` | Everything REST: spec ingestion, the endpoint DSL, auto-CRUD, seeds, response synthesis |

The test for "does this belong in MockCore?" is: *would every protocol extension want it, with
no knowledge of any particular schema language?* If so, propose it there rather than
duplicating it in one protocol. A change to MockCore and the protocols that use it is one pull
request: build and test the whole package.

## Getting started

1. Install a **Swift 6.3** toolchain — Xcode 26.5+ on macOS, a [swift.org](https://swift.org/install/)
   toolchain on Linux or Windows, or the `swift:6.3` Docker image (which is what CI uses).
2. Fork and clone the repository.
3. Build and test from the command line:

   ```sh
   swift build
   swift test
   ```

   `make check` runs everything a pull request must pass — lint, build, tests, and the
   documentation build — in one step. `swift test --filter MockRESTCoreTests` (or any test
   target) keeps the loop short while you iterate.

   On macOS you can also open `Package.swift` in Xcode 26.5 or later.

The only dependencies are Yams (in `MockCore`) and SwiftNIO (in the transport modules only —
`MockCore`, `MockQLCore` and `MockRESTCore` must stay NIO-free and portable). They resolve from
GitHub; nothing else is required beyond the toolchain.

## Reporting bugs and requesting features

- Search [existing issues](https://github.com/AlexNachbaur/mockkit-swift/issues) first.
- Use the issue templates — a minimal reproduction (the schema or spec excerpt, seed data, the
  GraphQL operation or HTTP request, and the observed vs. expected response) makes bugs
  dramatically faster to fix.
- For anything security-sensitive, **do not open a public issue** — see [SECURITY.md](SECURITY.md).

## Code style

Formatting is enforced by `swift-format` using the checked-in [.swift-format](.swift-format)
configuration. CI will fail on lint violations, so run this before pushing (`make lint`; `make
format` applies the fixes):

```sh
swift format lint --strict --recursive Sources Tests Package.swift
```

The DocC catalogs must build with **zero warnings**, and CI does not build them — `make docs`
(part of `make check`) is the only place a documentation regression is caught.

Beyond formatting, the project follows these rules:

- **120-character line length, 4-space indentation.**
- **No force unwraps** (`!`) in production code.
- **No `DispatchQueue`** — use Swift concurrency (`async`/`await`, actors, structured tasks).
- **Prefer value types** (structs, enums with cases) over reference types.
- **Never use caseless enums as namespaces.** Enums are for enumerated values only. For
  singletons or groupings of static members, use a `struct` with static properties or a
  `final class` with `static let shared`.
- **Error messages are a product feature.** Every user-facing error carries a source name,
  location, or document path (`paths./users/{id}.get.responses.200`, `data.User[0].email`), and
  a "did you mean" suggestion where a typo is plausible. Never regress diagnostic quality.
- **Stay cross-platform.** Every product supports macOS, iOS, Linux, Windows, and Android.
  Don't import Apple-only frameworks in library targets, and stick to Foundation APIs available
  in swift-corelibs-foundation. CI builds and tests on macOS, an iOS simulator, Linux, Windows,
  and an Android emulator, and must pass on all five.

## Pull requests

- Branch from `main`; keep PRs focused on a single change.
- Add or update tests for any behavioral change, next to the module they cover (`AGENTS.md`
  lists the test targets). Full-stack HTTP/WebSocket behavior belongs in the integration
  targets, and cross-protocol behavior in `Tests/MockRESTIntegrationTests`.
- Update documentation (doc comments, DocC, the guides in `docs/`) when the public API changes.
- Note user-visible changes under the **Unreleased** heading in [CHANGELOG.md](CHANGELOG.md),
  naming the product they affect.
- Make sure `make check` passes locally (lint, build, tests, and the DocC build).

MockKit follows semantic versioning, and every product shares one version: a breaking change
to the public API of any product — MockCore's included, since MockQL and MockREST re-export it
— needs a new major version and a changelog entry saying what to change.

## Code review

Every pull request is reviewed by Claude. The review is posted by the **codergirl-reviewer** app
as inline comments and a **Claude review** check. That check is required, and `main` also
requires every review thread to be resolved before a merge: fix what the comment describes, or
reply with why it does not apply, then resolve it. A thread resolved without either is reopened.

The review runs on the maintainer's infrastructure, not in this repository — there is no review
workflow or secret here, and nothing to set up in your fork. A pull request **from a fork** is
reviewed once a maintainer adds the `claude-review` label, which is the maintainer accepting the
submission for review; later pushes are re-reviewed while the label stays. Until then the
**Claude review** check is missing and the pull request cannot merge, but nothing stops you
building, testing, or opening it.

## Design discussions

Larger changes (the `MockService` seam, the state model, the transport, new DSL surface,
spec-ingestion scope) should start as an issue describing the problem and the proposed approach
before any code is written. Design documents live in [docs/](docs/): the platform
[architecture](docs/architecture.md), and each protocol's design notes under
[docs/mockql/design/](docs/mockql/design/) and [docs/mockrest/design/](docs/mockrest/design/).

## Code of conduct

All participation in this project is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md).
