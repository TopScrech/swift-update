import Foundation
import UpdateCore

struct Options {
    var path = FileManager.default.currentDirectoryPath
    var all = false
    var json = false
    var prereleases = false
    var check = false
    var help = false

    static let usage = """
    swift-update [--path <directory|Package.resolved>] [--all] [--json] [--prereleases] [--check]

    Check resolved Swift dependencies against upstream Git tags
    Includes direct and transitive dependencies, without changing files

      --path          Swift package, Xcode project/workspace or lockfile path
      --all           Include up-to-date packages in text output
      --json          Print all results as JSON
      --prereleases   Include prerelease tags
      --check         Exit 1 when updates are available
      --help          Show help

    Exit codes: 0 success, 1 outdated with --check, 2 lookup or input failure
    Branch/revision pins are reported as unknown, not as available upgrades
    """

    init(arguments: [String]) throws {
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--path":
                guard let value = iterator.next(), !value.hasPrefix("--") else { throw UpdateError.message("--path requires a value") }
                path = value
            case "--all": all = true
            case "--json": json = true
            case "--prereleases": prereleases = true
            case "--check": check = true
            case "--help", "-h": help = true
            default: throw UpdateError.message("Unknown argument: \(argument)")
            }
        }
    }
}
