import Foundation
import UpdateCore

@main
struct SwiftUpdate {
    static func main() async {
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            if options.help {
                print(Options.usage)
                return
            }
            let file = try ResolvedFile.locate(in: URL(filePath: options.path))
            let resolved = try JSONDecoder().decode(ResolvedFile.self, from: Data(contentsOf: file))
            let client = GitClient()
            var results: [UpdateResult] = []
            for pin in resolved.pins.sorted(by: { $0.identity < $1.identity }) {
                do {
                    let tags = try await client.tags(at: pin.location)
                    results.append(UpdateResult(pin: pin, tags: tags, includePrereleases: options.prereleases))
                } catch {
                    results.append(UpdateResult(pin: pin, error: error))
                }
            }
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
            FileHandle.standardError.write(Data("swift-update: \(error.localizedDescription)\n".utf8))
            exit(2)
        }
    }
}
