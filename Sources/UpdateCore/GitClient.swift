import Foundation

public actor GitClient {
    public init() {}

    public func tags(at location: String) async throws -> [String] {
        // Restrict transports so lockfiles cannot invoke Git remote helpers or local commands
        guard let url = URL(string: location),
              let scheme = url.scheme, ["https", "http", "ssh"].contains(scheme),
              url.host != nil else {
            throw UpdateError.message("Unsupported repository URL — expected HTTPS, HTTP or SSH")
        }
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appending(path: "stdout")
        let errorURL = directory.appending(path: "stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        let errors = try FileHandle(forWritingTo: errorURL)
        defer { try? output.close(); try? errors.close() }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-c", "credential.interactive=false", "ls-remote", "--tags", "--refs", "--", location]
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_SSH_COMMAND"] = "ssh -oBatchMode=yes -oConnectTimeout=15 -oStrictHostKeyChecking=yes"
        environment["GIT_ALLOW_PROTOCOL"] = "https:http:ssh"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        do {
            while process.isRunning {
                try Task.checkCancellation()
                guard ContinuousClock.now < deadline else { throw UpdateError.message("Repository lookup timed out") }
                try await Task.sleep(for: .milliseconds(50))
            }
        } catch {
            if process.isRunning { process.terminate() }
            throw error
        }
        guard process.terminationStatus == 0 else {
            // Git output can include credentials embedded in repository URLs
            throw UpdateError.message("Git could not read remote tags (exit \(process.terminationStatus)) — check repository access")
        }
        return try String(contentsOf: outputURL, encoding: .utf8).split(separator: "\n").compactMap {
            let fields = $0.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2, fields[1].hasPrefix("refs/tags/") else { return nil }
            return String(fields[1].dropFirst("refs/tags/".count))
        }
    }
}
