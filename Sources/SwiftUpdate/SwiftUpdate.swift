import Foundation
import UpdateCore

@main
struct SwiftUpdate {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            let options = try Options(arguments: arguments)
            if options.help {
                print(Options.usage)
                return
            }
            if options.xcode {
                do {
                    let outcome = try await BuildCheckRunner().run(
                        path: URL(filePath: options.path),
                        includePrereleases: options.prereleases,
                        useCache: !options.noCache
                    )
                    print(outcome.cached
                        ? "Package update check: cached results (15-minute TTL)"
                        : "Package update check: fetched release tags and branch HEADs")
                    for message in outcome.report.messages { print(BuildCheckReport.warning(message)) }
                } catch {
                    print(BuildCheckReport.warning("Check unavailable (\(error.localizedDescription)); will retry next build"))
                }
                return
            }
            let file = try ResolvedFile.locate(in: URL(filePath: options.path))
            let resolved = try JSONDecoder().decode(ResolvedFile.self, from: Data(contentsOf: file))
            let results = await DependencyChecker().check(pins: resolved.pins, includePrereleases: options.prereleases)
            if options.json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                FileHandle.standardOutput.write(try encoder.encode(results))
                print()
            } else {
                print("PACKAGE\tCURRENT\tLATEST\tSTATUS")
                for result in results where options.all || result.status != "up-to-date" {
                    print("\(result.package)\t\(result.current)\t\(result.latest ?? "—")\t\(result.status)")
                    if let message = result.message { print("  \(message)") }
                }
                print("\(results.filter { $0.status == "outdated" }.count) outdated, \(results.filter { $0.status == "unknown" }.count) unknown, \(results.filter { $0.status == "error" }.count) failed")
            }
            if results.contains(where: { $0.status == "error" }) { exit(2) }
            if options.check && results.contains(where: { $0.status == "outdated" }) { exit(1) }
        } catch {
            if arguments.contains("--xcode") {
                print(BuildCheckReport.warning("Check unavailable (\(error.localizedDescription)); will retry next build"))
                return
            }
            FileHandle.standardError.write(Data("swift-update: \(error.localizedDescription)\n".utf8))
            exit(2)
        }
    }
}
