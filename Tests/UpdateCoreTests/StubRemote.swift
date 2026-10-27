import Foundation
@testable import UpdateCore

actor StubRemote: RemoteRepository {
    var requests = 0
    var failing = false

    func setFailing(_ value: Bool) { failing = value }

    func tags(at location: String) async throws -> [String] {
        requests += 1
        try await Task.sleep(for: .milliseconds(20))
        if failing { throw UpdateError.message("Offline") }
        return ["1.0.0", "2.0.0"]
    }

    func revision(at location: String, branch: String) async throws -> String {
        requests += 1
        if failing { throw UpdateError.message("Offline") }
        return "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    }
}
