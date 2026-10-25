import MockRESTCore
import Testing

/// MockKit releases every product under one version; MockCore's tests tie that version to the
/// changelog.
@Suite struct VersionTests {
    @Test func versionIsThePackageVersion() {
        #expect(MockRESTVersion.current == MockCoreVersion.current)
    }
}
