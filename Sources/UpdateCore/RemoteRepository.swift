public protocol RemoteRepository: Sendable {
    func tags(at location: String) async throws -> [String]
    func revision(at location: String, branch: String) async throws -> String
}
