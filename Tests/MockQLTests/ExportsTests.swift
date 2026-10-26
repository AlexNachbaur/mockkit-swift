import MockQL
import Testing

@Test func coreModulesAreReExported() {
    // `GraphQLValue` lives in MockQLCore and `MockKitVersion` in MockCore; reaching both
    // through `import MockQL` alone proves the re-export chain works.
    let value: GraphQLValue = .null
    #expect(value == .null)
    #expect(!MockKitVersion.current.isEmpty)
}
