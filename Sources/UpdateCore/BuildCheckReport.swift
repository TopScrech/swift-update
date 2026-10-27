public struct BuildCheckReport: Codable, Sendable {
    public let messages: [String]
    public let success: Bool

    public init(results: [UpdateResult]) {
        var messages: [String] = []
        var success = true
        for result in results {
            switch result.status {
            case "outdated":
                if let branch = result.branch {
                    messages.append("\(result.package) branch \(branch) has a different remote HEAD (\(result.current.prefix(12)) -> \(result.latest?.prefix(12) ?? "unknown")); update package dependencies")
                } else {
                    messages.append("\(result.package) has an update (\(result.current) -> \(result.latest ?? "unknown")); update package dependencies")
                }
            case "up-to-date": break
            default:
                success = false
                if let branch = result.branch {
                    messages.append("Could not check \(result.package) branch \(branch); will retry next build")
                } else {
                    messages.append("Could not determine the latest version of \(result.package); will retry next build")
                }
            }
        }
        self.messages = messages
        self.success = success
    }

    public static func warning(_ message: String) -> String {
        "warning: Package updates: " + message.split(whereSeparator: { $0.isNewline }).joined(separator: " ")
    }
}
