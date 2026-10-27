# swift-update

Check Swift package dependencies for newer releases, using Swift and SPM

No Homebrew, Mint, Python runtime, or third-party Swift dependencies required
Requires Swift 6.4 / Xcode 27 or later, macOS 13 or later, and Git provided by Xcode or Command Line Tools

## SPM installation

The package exports `SwiftUpdatePlugin`, the `swift-update` executable, and the `UpdateCore` library

Add `https://github.com/TopScrech/swift-update` using Xcode → File → Add Package Dependencies, with a minimum version of `0.1.0`
Do not link the executable or library into your app target just to use the plugin
Invoke `SwiftUpdatePlugin` from the project's package command menu and allow its requested network access

For a Swift package, add the repository to `dependencies` in `Package.swift`:

```swift
.package(url: "https://github.com/TopScrech/swift-update.git", from: "0.1.0")
```
Command plugins do not need an entry in a target's build-tool `plugins` list
Run from the consuming package directory:

```sh
swift package --scratch-path /tmp/swift-update-client-build --allow-network-connections all swift-update
```

The plugin is a command plugin, not a build-tool plugin: it checks on demand because upstream tag lookup requires network permission

## Run from this checkout

From this package directory:

```sh
swift run --scratch-path /tmp/swift-update-build swift-update --path /path/to/your/project
```

Or invoke the bundled plugin against a project:

```sh
swift package --scratch-path /tmp/swift-update-build --allow-network-connections all swift-update --path /path/to/your/project
```

Scratch paths keep build artifacts outside the repository
Opening `Package.swift` in Xcode also supports building the executable and running the tests on My Mac

## Options

| Option | Behavior |
| --- | --- |
| `--path <path>` | Scan a Swift package directory, Xcode project/workspace, or explicit `Package.resolved` |
| `--all` | Include up-to-date packages in text output |
| `--json` | Return every package result as a JSON array |
| `--prereleases` | Include semantic-version prerelease tags |
| `--check` | Exit 1 if any dependency has a newer version |
| `--help` | Display usage |

Exit status is 0 on success, 1 for available updates when `--check` is set, and 2 for input or repository lookup failures
Lookup failures take precedence over available updates

## Behavior

- Reads Package.resolved schemas 1, 2, and 3
- Includes both direct and transitive Git dependencies
- Discovers root Swift package lockfiles and shared Xcode project/workspace lockfiles
- Requests an explicit path if multiple Xcode lockfiles are found
- Uses `git ls-remote` without cloning repositories
- Compares semantic versions numerically, including prerelease ordering
- Accepts standard version tags such as `1.2.3` and `v1.2.3`
- Excludes prerelease tags unless `--prereleases` is passed
- Reports branch/revision pins and repositories without usable version tags as `unknown`
- Supports HTTPS, HTTP, and `ssh://` repository URLs
- Uses existing Git credentials, disables interactive prompts, and limits each lookup to 30 seconds
- Reports individual lookup failures while continuing through remaining packages

Reports the newest upstream tag, including versions outside your declared requirements
It does not determine whether an update is compatible, resolve dependencies, rewrite manifests, or modify lockfiles
Registry dependencies and SCP-style SSH URLs such as `git@host:owner/repo.git` are not supported in this initial version
Network lookups are sequential

## Verification

Built through Xcode's native MCP server using `swift-update-Package` on My Mac
All 12 Swift Testing cases passed, covering version ordering, invalid tags, prerelease filtering, and lockfile schemas 1–3
A live CLI smoke test checked a public GitHub repository and verified JSON output and exit status 1 with `--check`

The command plugin implementation uses the installed PackagePlugin and XcodeProjectPlugin APIs, but host execution of the plugin has not yet been verified
