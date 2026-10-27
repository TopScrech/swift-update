import Foundation

public struct SemanticVersion: Comparable, Sendable {
    public let components: [Int]
    public let prerelease: [String]

    public init?(_ tag: String) {
        let value = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let metadata = value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        let parts = metadata[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              numbers.allSatisfy({ Self.isNumber(String($0)) && ($0.count == 1 || !$0.hasPrefix("0")) }) else { return nil }
        let parsed = numbers.compactMap { Int($0) }
        guard parsed.count == 3 else { return nil }
        let identifiers = parts.count == 2 ? parts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init) : []
        guard identifiers.allSatisfy({ Self.isIdentifier($0) && (!Self.isNumber($0) || $0.count == 1 || !$0.hasPrefix("0")) }) else { return nil }
        if metadata.count == 2 {
            guard metadata[1].split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ Self.isIdentifier(String($0)) }) else { return nil }
        }
        components = parsed
        prerelease = identifiers
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.components != rhs.components { return lhs.components.lexicographicallyPrecedes(rhs.components) }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            let leftNumeric = isNumber(left)
            let rightNumeric = isNumber(right)
            if leftNumeric && rightNumeric {
                return left.count == right.count ? left < right : left.count < right.count
            }
            if leftNumeric != rightNumeric { return leftNumeric }
            return left < right
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private static func isNumber(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func isIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
        }
    }
}
