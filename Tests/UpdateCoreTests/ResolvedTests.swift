import Foundation
import Testing
@testable import UpdateCore

struct ResolvedTests {
    @Test(arguments: [2, 3])
    func modernSchemas(version: Int) throws {
        let json = """
        {"version": \(version), "pins": [{"identity":"example", "location":"https://example.com/repo.git", "state":{"version":"1.0.0","revision":"abc"}}]}
        """
        let file = try JSONDecoder().decode(ResolvedFile.self, from: Data(json.utf8))
        let pin = try #require(file.pins.first)
        let stable = UpdateResult(pin: pin, tags: ["1.1.0", "2.0.0-beta.1"], includePrereleases: false)
        #expect(stable.latest == "1.1.0")
        #expect(stable.status == "outdated")
        let prerelease = UpdateResult(pin: pin, tags: ["1.1.0", "2.0.0-beta.1"], includePrereleases: true)
        #expect(prerelease.latest == "2.0.0-beta.1")
    }

    @Test func legacyBranchPin() throws {
        let json = """
        {"version":1,"object":{"pins":[{"package":"Example","repositoryURL":"https://example.com/repo.git","state":{"branch":"main","revision":"abc"}}]}}
        """
        let file = try JSONDecoder().decode(ResolvedFile.self, from: Data(json.utf8))
        let result = UpdateResult(pin: try #require(file.pins.first), tags: ["2.0.0"], includePrereleases: false)
        #expect(result.status == "unknown")
    }
}
