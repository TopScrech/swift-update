import Foundation
import PackagePlugin

@main
struct SwiftUpdatePlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try run(tool: context.tool(named: "swift-update").url, directory: context.package.directoryURL, arguments: arguments)
    }

    private func run(tool: URL, directory: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool
        process.arguments = ["--path", directory.path] + arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            Diagnostics.error("swift-update exited with status \(process.terminationStatus)")
            throw PluginFailure.unsuccessful
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftUpdatePlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        try run(tool: context.tool(named: "swift-update").url, directory: context.xcodeProject.directoryURL, arguments: arguments)
    }
}
#endif
