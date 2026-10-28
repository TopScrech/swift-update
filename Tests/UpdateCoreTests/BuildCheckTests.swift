import Foundation
import Testing
@testable import UpdateCore

struct BuildCheckTests {
    private func lockfile(version: String = "1.0.0", branch: String? = nil) throws -> Data {
        var state = ["revision": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
        if let branch { state["branch"] = branch } else { state["version"] = version }
        return try JSONSerialization.data(withJSONObject: ["version": 3, "pins": [["identity": "example", "location": "https://example.com/repo.git", "state": state]]])
    }

    @Test func cachedWarningsAndLockfileInvalidation() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Package.resolved")
        try lockfile().write(to: file)
        let remote = StubRemote()
        let runner = BuildCheckRunner(cacheDirectory: directory.appending(path: "cache"), remote: remote)
        let first = try await runner.run(path: file)
        let second = try await runner.run(path: file)
        #expect(!first.cached)
        #expect(second.cached)
        #expect(second.report.messages == first.report.messages)
        #expect(second.report.messages.first == "Update package dependency: example 1.0.0 -> 2.0.0")
        #expect(await remote.requests == 1)
        try lockfile(version: "2.0.0").write(to: file)
        let changed = try await runner.run(path: file)
        #expect(!changed.cached)
        #expect(changed.report.messages.isEmpty)
        #expect(await remote.requests == 2)
    }

    @Test func failuresAreRetried() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Package.resolved")
        try lockfile().write(to: file)
        let remote = StubRemote()
        await remote.setFailing(true)
        let runner = BuildCheckRunner(cacheDirectory: directory.appending(path: "cache"), remote: remote)
        let failed = try await runner.run(path: file)
        #expect(!failed.report.success)
        await remote.setFailing(false)
        let retry = try await runner.run(path: file)
        #expect(!retry.cached)
        #expect(retry.report.success)
        #expect(await remote.requests == 2)
    }

    @Test func simultaneousChecksShareCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Package.resolved")
        try lockfile().write(to: file)
        let remote = StubRemote()
        let runner = BuildCheckRunner(cacheDirectory: directory.appending(path: "cache"), remote: remote)
        async let first = runner.run(path: file)
        async let second = runner.run(path: file)
        let outcomes = try await [first, second]
        #expect(outcomes.filter(\.cached).count == 1)
        #expect(await remote.requests == 1)
    }

    @Test func branchWarningUsesRemoteHead() async throws {
        let resolved = try JSONDecoder().decode(ResolvedFile.self, from: lockfile(branch: "main"))
        let remote = StubRemote()
        let results = await DependencyChecker(remote: remote).check(pins: resolved.pins)
        let report = BuildCheckReport(results: results)
        #expect(report.success)
        #expect(report.messages.first == "Update package dependency: example branch main aaaaaaaaaaaa -> bbbbbbbbbbbb")
        #expect(await remote.requests == 1)
    }

    @Test func freshModeAndToolVersionInvalidateCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Package.resolved")
        try lockfile().write(to: file)
        let remote = StubRemote()
        let cache = directory.appending(path: "cache")
        let runner = BuildCheckRunner(cacheDirectory: cache, remote: remote, toolVersion: "1")
        _ = try await runner.run(path: file)
        let fresh = try await runner.run(path: file, useCache: false)
        #expect(!fresh.cached)
        let updated = try await BuildCheckRunner(cacheDirectory: cache, remote: remote, toolVersion: "2").run(path: file)
        #expect(!updated.cached)
        #expect(await remote.requests == 3)
    }

    @Test func fixedRevisionsDoNotQueryReleases() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "Package.resolved")
        let json = """
        {"version":3,"pins":[{"identity":"fixed","location":"https://example.com/repo.git","state":{"revision":"abc"}}]}
        """
        try Data(json.utf8).write(to: file)
        let remote = StubRemote()
        let outcome = try await BuildCheckRunner(cacheDirectory: directory.appending(path: "cache"), remote: remote).run(path: file)
        #expect(outcome.report.success)
        #expect(outcome.report.messages.isEmpty)
        #expect(await remote.requests == 0)
    }

    @Test func warningCannotInjectExtraDiagnostics() {
        #expect(BuildCheckReport.warning("example\nerror: fake") == "warning: example error: fake")
    }

    @Test func cacheExpirationAndClockRollback() {
        let report = BuildCheckReport(results: [])
        let now = Date.now
        let cached = BuildCheckCacheEntry(fingerprint: "a", checkedAt: now, report: report)
        #expect(cached.isValid(fingerprint: "a", now: now.addingTimeInterval(899)))
        #expect(!cached.isValid(fingerprint: "a", now: now.addingTimeInterval(900)))
        #expect(!cached.isValid(fingerprint: "a", now: now.addingTimeInterval(-1)))
        #expect(!cached.isValid(fingerprint: "b", now: now))
    }
}
