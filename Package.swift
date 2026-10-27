// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-update",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "swift-update", targets: ["SwiftUpdate"]),
        .library(name: "UpdateCore", targets: ["UpdateCore"]),
        .plugin(name: "SwiftUpdatePlugin", targets: ["SwiftUpdatePlugin"])
    ],
    targets: [
        .target(name: "UpdateCore"),
        .executableTarget(name: "SwiftUpdate", dependencies: ["UpdateCore"]),
        .plugin(
            name: "SwiftUpdatePlugin",
            capability: .command(
                intent: .custom(verb: "swift-update", description: "Check Swift package updates"),
                permissions: [.allowNetworkConnections(scope: .all(), reason: "Read upstream Git tags to check dependency versions")]
            ),
            dependencies: ["SwiftUpdate"]
        ),
        .testTarget(name: "UpdateCoreTests", dependencies: ["UpdateCore"])
    ]
)
