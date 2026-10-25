// MockREST is built on the MockCore platform; re-exporting keeps `import MockRESTCore` the
// only import needed for the portable engine (MockValue, SeedSource, FieldGenerator, …).
@_exported import MockCore

/// Package version information for MockREST.
public struct MockRESTVersion {
    /// The current version of MockREST: the MockKit package version, since every product is
    /// released together.
    public static let current = MockCoreVersion.current
}
