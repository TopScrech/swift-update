import Foundation

public struct ResolvedFile: Decodable, Sendable {
    public let pins: [ResolvedPin]

    private enum CodingKeys: String, CodingKey { case version, pins, object }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .version)
        guard (1...3).contains(version) else {
            throw UpdateError.message("Unsupported Package.resolved schema: \(version)")
        }
        if version == 1 {
            let object = try values.nestedContainer(keyedBy: CodingKeys.self, forKey: .object)
            pins = try object.decode([ResolvedPin].self, forKey: .pins)
        } else {
            pins = try values.decode([ResolvedPin].self, forKey: .pins)
        }
    }

    public static func locate(in path: URL) throws -> URL {
        let manager = FileManager.default
        if path.lastPathComponent == "Package.resolved", manager.fileExists(atPath: path.path) { return path }
        let candidates = [
            path.appending(path: "Package.resolved"),
            path.appending(path: "xcshareddata/swiftpm/Package.resolved"),
            path.appending(path: "project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        ]
        if let direct = candidates.first(where: { manager.fileExists(atPath: $0.path) }) { return direct }
        let children = try manager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
        let matches = children.filter { ["xcodeproj", "xcworkspace"].contains($0.pathExtension) }.flatMap {
            [ $0.appending(path: "xcshareddata/swiftpm/Package.resolved"),
              $0.appending(path: "project.xcworkspace/xcshareddata/swiftpm/Package.resolved") ]
        }.filter { manager.fileExists(atPath: $0.path) }
        guard matches.count == 1, let result = matches.first else {
            throw UpdateError.message(matches.isEmpty
                ? "No Package.resolved found — resolve dependencies first or pass --path"
                : "Multiple lockfiles found — pass --path with the intended Package.resolved")
        }
        return result
    }
}
