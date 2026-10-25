# Changelog

All notable changes to MockKit will be documented in this file. Every product is released
together, so one version covers them all; entries name the product they affect.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). While MockKit is
pre-1.0, a minor release may break the public API; each break is called out here.

## [Unreleased]

## [0.6.0] - 2026-10-25

MockKit 0.6.0 is the first release of mockcore-swift, mockql-swift and mockrest-swift as one
package, `mockkit-swift`. Those three repositories are retired. Their history is kept here: the
git history, the release points as `mockcore-0.1.2`-style tags, and the changelogs in
[docs/changelogs/](docs/changelogs/). The version continues from the highest of the three
(mockql 0.5.0), so it is newer than every release of any of them.

### Migrating from the separate packages

Module and product names are unchanged, so no `import` changes. Only the package dependency
does:

```swift
// Before: one dependency per package
.package(url: "https://github.com/AlexNachbaur/mockql-swift.git", from: "0.5.0"),
.package(url: "https://github.com/AlexNachbaur/mockrest-swift.git", from: "0.1.1"),
// …with products from each:
.product(name: "MockQL", package: "mockql-swift"),

// After: one dependency, any of its products
.package(url: "https://github.com/AlexNachbaur/mockkit-swift.git", from: "0.6.0"),
// …
.product(name: "MockQL", package: "mockkit-swift"),
.product(name: "MockREST", package: "mockkit-swift"),
```

Depend only on the products you use; SwiftPM builds only their targets. The third-party
dependencies (Yams, SwiftNIO) are the ones every product already pulled in through MockCore.

### Changed

- **One version for every product.** `MockQLVersion.current` and `MockRESTVersion.current`
  now equal `MockCoreVersion.current` (`"0.6.0"`), the package version.
- **MockREST's test-only dependency on MockQL no longer reaches consumers.** The
  cross-protocol integration suite used to make every MockREST user resolve mockql-swift; it is
  now an internal test dependency.

### What else is in 0.6.0

This release also ships everything that was unreleased in the three packages after mockcore
0.1.2, mockql 0.5.0 and mockrest 0.1.1. The full notes are in each product's changelog. These
changes alter behavior a test suite may depend on:

- **MockCore** ([full notes](docs/changelogs/mockcore.md#060---2026-10-25)):
  - Field-name inference matches whole words, not substrings, so **generated values for fields
    that matched only by substring differ** (`updated`, `hourly` and `title` are no longer a
    timestamp, a URL and a name). Bind a generator to pin a shape.
  - `MockHost.stop()` is idempotent and drains in-flight requests before shutting services
    down.
- **MockQL** ([full notes](docs/changelogs/mockql.md#060---2026-10-25)):
  - Requests that used to be answered leniently are now errors:
    - a mutation sent with `GET`;
    - an `Int` outside 32 bits;
    - a negative `first`/`last`;
    - an undeclared variable;
    - ambiguous configuration.
  - Schemas are checked at load for interface conformance and default-value types.
  - Request errors omit `data` instead of returning `null` (spec §7.1.2).
  - New: backward pagination (`last`/`before`), and queries and mutations over the WebSocket.
- **MockREST** ([full notes](docs/changelogs/mockrest.md#060---2026-10-25)):
  - Required query/header parameters and nested `required` fields are now enforced.
  - Filtering keys on schema properties, not on what the store happens to contain.
  - A declared non-JSON `Content-Type` is believed.
  - `$ref`s into `components.parameters`, `components.requestBodies` and
    `components.responses` resolve.

[Unreleased]: https://github.com/AlexNachbaur/mockkit-swift/compare/0.6.0...HEAD
[0.6.0]: https://github.com/AlexNachbaur/mockkit-swift/releases/tag/0.6.0
