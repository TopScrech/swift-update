import Foundation

public struct ResolvedPin: Decodable, Sendable {
    public let identity: String
    public let location: String
    public let version: String?
    public let branch: String?
    public let revision: String?

    private enum CodingKeys: String, CodingKey {
        case identity, package, location, repositoryURL, state
    }

    private enum StateKeys: String, CodingKey {
        case version, branch, revision
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identity = try values.decodeIfPresent(String.self, forKey: .identity) ?? values.decode(String.self, forKey: .package)
        location = try values.decodeIfPresent(String.self, forKey: .location) ?? values.decode(String.self, forKey: .repositoryURL)
        let state = try values.nestedContainer(keyedBy: StateKeys.self, forKey: .state)
        version = try state.decodeIfPresent(String.self, forKey: .version)
        branch = try state.decodeIfPresent(String.self, forKey: .branch)
        revision = try state.decodeIfPresent(String.self, forKey: .revision)
    }
}
