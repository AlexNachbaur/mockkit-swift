import MockCore
import Testing

@testable import MockQLCore

/// MockKit releases every product under one version; MockCore's tests tie that version to the
/// changelog.
@Test func versionIsThePackageVersion() {
    #expect(MockQLVersion.current == MockCoreVersion.current)
}
