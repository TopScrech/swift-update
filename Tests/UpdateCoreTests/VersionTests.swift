import Testing
@testable import UpdateCore

struct VersionTests {
    @Test func semanticOrdering() throws {
        let tags = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0", "1.10.0", "2.0.0"]
        let versions = try tags.map { try #require(SemanticVersion($0)) }
        for (left, right) in zip(versions, versions.dropFirst()) { #expect(left < right) }
    }

    @Test func metadataAndPrefix() {
        #expect(SemanticVersion("v1.2.3+build.5") == SemanticVersion("1.2.3"))
    }

    @Test(arguments: ["1.0", "v1.0", "1.0.0", "v1.0.0"])
    func omittedPatchEqualsZero(tag: String) throws {
        let version = try #require(SemanticVersion(tag))
        #expect(version == SemanticVersion("1.0.0"))
        #expect(version.components == [1, 0, 0])
        #expect(version < (try #require(SemanticVersion("1.0.1"))))
    }

    @Test func omittedPatchPreservesSuffixes() {
        #expect(SemanticVersion("v1.2-beta.1+build.5") == SemanticVersion("1.2.0-beta.1"))
    }

    @Test(arguments: ["", "1", "v1", "1.", ".1", "1..2", "01.2", "1.02", "1.2-", "1.2-01", "1.2+", "01.2.3", "1.2.3-", "1.2.3-01", "1.2.3+", "release-1.2.3", "1.2.3.4"])
    func invalidVersion(tag: String) { #expect(SemanticVersion(tag) == nil) }
}
