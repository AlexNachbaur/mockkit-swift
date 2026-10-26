// MockQL is built on the MockCore platform: the value model, state store, generators, seeded
// RNG, seed primitives, and diagnostics all live there and are shared with sibling extensions
// like MockREST. Re-exporting keeps `import MockQLCore` the only import consumers need for
// `StateStore`, `FieldGenerator`, `SeedSource` and the rest.
@_exported import MockCore

/// The dynamic value type MockQL is built on.
///
/// The GraphQL name for MockCore's `MockValue`, the value tree every MockKit protocol shares —
/// which is what lets REST and GraphQL mocks use one state store. Seed documents, operation
/// arguments, stored records, and response payloads are all `GraphQLValue` trees.
public typealias GraphQLValue = MockValue

/// The load-time validation error type MockQL throws for schema, seed, operation-syntax, and
/// configuration problems.
///
/// The GraphQL name for MockCore's `MockError`, the diagnostic type every MockKit protocol
/// shares.
public typealias MockQLError = MockError
