import CryptoKit
import Darwin
import Foundation

public struct BuildCheckRunner: Sendable {
    private let cacheDirectory: URL
    private let checker: DependencyChecker
    private let toolVersion: String

    public init(
        cacheDirectory: URL = URL.cachesDirectory.appending(path: "SwiftUpdate/BuildChecks"),
        remote: any RemoteRepository = GitClient(),
        toolVersion: String = "1.1.1"
    ) {
        self.cacheDirectory = cacheDirectory
        checker = DependencyChecker(remote: remote)
        self.toolVersion = toolVersion
    }

    public func run(path: URL, includePrereleases: Bool = false, useCache: Bool = true) async throws -> BuildCheckOutcome {
        let file = try ResolvedFile.locate(in: path).resolvingSymlinksInPath().standardizedFileURL
        let key = Self.digest(Data(file.path.utf8))
        let directory = cacheDirectory.appending(path: key)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = directory.appending(path: "check.lock")
        let descriptor = open(lockURL.path, O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw UpdateError.message("Could not open dependency check cache lock") }
        let lock = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? lock.close() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        while flock(lock.fileDescriptor, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EINTR else {
                throw UpdateError.message("Could not lock dependency check cache")
            }
            guard ContinuousClock.now < deadline else { throw UpdateError.message("Another dependency check is still running; will retry next build") }
            try await Task.sleep(for: .milliseconds(100))
        }
        defer { flock(lock.fileDescriptor, LOCK_UN) }
        // Read after acquiring the lock so concurrent builds observe the last completed check
        let data = try Data(contentsOf: file)
        let fingerprint = Self.digest(data + Data("\(toolVersion)|\(includePrereleases)".utf8))
        let cacheURL = directory.appending(path: "results.json")
        if useCache,
           let cachedData = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode(BuildCheckCacheEntry.self, from: cachedData),
           cached.isValid(fingerprint: fingerprint, now: .now) {
            return BuildCheckOutcome(report: cached.report, cached: true)
        }
        let resolved = try JSONDecoder().decode(ResolvedFile.self, from: data)
        let pins = resolved.pins.filter { $0.version != nil || $0.branch != nil }
        let results = await checker.check(pins: pins, includePrereleases: includePrereleases)
        let report = BuildCheckReport(results: results)
        if report.success {
            let entry = BuildCheckCacheEntry(fingerprint: fingerprint, checkedAt: .now, report: report)
            try JSONEncoder().encode(entry).write(to: cacheURL, options: .atomic)
        }
        return BuildCheckOutcome(report: report, cached: false)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            let hex = String($0, radix: 16)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }
}
