import Foundation

public struct UpdateResult: Encodable, Sendable {
    public let package: String
    public let current: String
    public let latest: String?
    public let status: String
    public let message: String?
    public let branch: String?

    public init(pin: ResolvedPin, tags: [String], includePrereleases: Bool) {
        branch = pin.branch
        package = pin.identity
        current = pin.version ?? pin.branch ?? pin.revision ?? "unknown"
        let versions = tags.compactMap { tag -> (String, SemanticVersion)? in
            guard let version = SemanticVersion(tag), includePrereleases || version.prerelease.isEmpty else { return nil }
            return (tag, version)
        }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
        latest = versions.last?.0
        message = nil
        if let version = pin.version, let currentVersion = SemanticVersion(version), let newest = versions.last {
            status = newest.1 > currentVersion ? "outdated" : "up-to-date"
        } else {
            status = "unknown"
        }
    }

    public init(pin: ResolvedPin, remoteRevision: String) {
        branch = pin.branch
        package = pin.identity
        current = pin.revision ?? "unknown"
        latest = remoteRevision
        status = pin.revision == nil ? "unknown" : (pin.revision == remoteRevision ? "up-to-date" : "outdated")
        message = nil
    }

    public init(pin: ResolvedPin, error: any Error) {
        branch = pin.branch
        package = pin.identity
        current = pin.version ?? pin.branch ?? pin.revision ?? "unknown"
        latest = nil
        status = "error"
        message = error.localizedDescription
    }
}
