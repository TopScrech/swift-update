public struct DependencyChecker: Sendable {
    private let remote: any RemoteRepository

    public init(remote: any RemoteRepository = GitClient()) {
        self.remote = remote
    }

    public func check(pins: [ResolvedPin], includePrereleases: Bool = false) async -> [UpdateResult] {
        await withTaskGroup(of: UpdateResult.self) { group in
            var iterator = pins.makeIterator()
            for _ in 0..<min(8, pins.count) {
                if let pin = iterator.next() {
                    group.addTask { await check(pin: pin, includePrereleases: includePrereleases) }
                }
            }
            var results: [UpdateResult] = []
            for await result in group {
                results.append(result)
                if let pin = iterator.next() {
                    group.addTask { await check(pin: pin, includePrereleases: includePrereleases) }
                }
            }
            return results.sorted { $0.package < $1.package }
        }
    }

    private func check(pin: ResolvedPin, includePrereleases: Bool) async -> UpdateResult {
        do {
            if let branch = pin.branch {
                let revision = try await remote.revision(at: pin.location, branch: branch)
                return UpdateResult(pin: pin, remoteRevision: revision)
            }
            guard pin.version != nil else {
                return UpdateResult(pin: pin, tags: [], includePrereleases: includePrereleases)
            }
            let tags = try await remote.tags(at: pin.location)
            return UpdateResult(pin: pin, tags: tags, includePrereleases: includePrereleases)
        } catch {
            return UpdateResult(pin: pin, error: error)
        }
    }
}
