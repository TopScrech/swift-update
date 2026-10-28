# swift-update

Check Swift package dependencies for newer releases, using Swift and SPM

No Homebrew, Mint, Python runtime, or third-party Swift dependencies required
Requires Swift 6.4 / Xcode 27 or later, macOS 13 or later, and Git provided by Xcode or Command Line Tools

## SPM installation

The package exports `SwiftUpdatePlugin`, the `swift-update` executable, and the `UpdateCore` library

Add `https://github.com/TopScrech/swift-update` using Xcode → File → Add Package Dependencies, with a minimum version of `1.1.0`
Do not link the executable or library into your app target just to use the plugin
Invoke `SwiftUpdatePlugin` from the project's package command menu and allow its requested network access

For a Swift package, add the repository to `dependencies` in `Package.swift`:

```swift
.package(url: "https://github.com/TopScrech/swift-update.git", from: "1.1.0")
```
Command plugins do not need an entry in a target's build-tool `plugins` list
Run from the consuming package directory:

```sh
swift package --scratch-path /tmp/swift-update-client-build --allow-network-connections all swift-update
```

The plugin is a command plugin, not a build-tool plugin: it checks on demand because upstream tag lookup requires network permission

## Automatic Xcode build checks

Use the remote `swift-update` executable as a dependency of a macOS-only build target (`SDKROOT = macosx`, `SUPPORTED_PLATFORMS = macosx`)
Make the app's package-update aggregate target depend on that Mac target so the CLI is built for the host even when the app targets iOS or visionOS
Keep the tool target build-only with `SKIP_INSTALL = YES`; do not embed the tool in the app

The aggregate target's build phase only invokes the SPM executable:

```sh
"$BUILT_PRODUCTS_DIR/swift-update" --xcode --path "$PROJECT_FILE_PATH" || true
```

This command replaces per-project wrapper files
The Swift executable owns release checks, branch HEAD comparisons, Xcode diagnostics, and caching
The phase needs network access, so use `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the package-update aggregate target

Xcode mode:

- Emits updates and lookup failures as `warning: Package updates: …`
- Checks both version pins and branch pins, skipping fixed revisions
- Keeps successful results, including update warnings, for 15 minutes
- Stores its cache under the user's caches directory, outside the project
- Invalidates cached results when the lockfile, tool version, or prerelease setting changes
- Serializes simultaneous checks of the same lockfile using an OS file lock
- Writes cached results atomically and never caches lookup failures
- Always exits 0 so dependency checks stay advisory

Use `--no-cache` with `--xcode` to fetch fresh results
The command plugin remains available for on-demand checks with its declared network permission

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
| `--xcode` | Emit advisory Xcode warnings with branch checks and a 15-minute cache |
| `--no-cache` | Bypass cached results in Xcode mode |
| `--help` | Display usage |

Exit status is 0 on success, 1 for available updates when `--check` is set, and 2 for input or repository lookup failures
Lookup failures take precedence over available updates in normal CLI mode
Xcode mode always exits 0, including on malformed input or lookup failures

## Behavior

- Reads Package.resolved schemas 1, 2, and 3
- Includes both direct and transitive Git dependencies
- Discovers root Swift package lockfiles and shared Xcode project/workspace lockfiles
- Requests an explicit path if multiple Xcode lockfiles are found
- Uses `git ls-remote` without cloning repositories
- Compares semantic versions numerically, including prerelease ordering
- Accepts version tags such as `1.2.3` and `v1.2.3`, treating omitted patch components in `1.2` and `v1.2` as zero
- Excludes prerelease tags unless `--prereleases` is passed
- Checks branch pins against their remote HEADs
- Reports fixed revisions and repositories without usable version tags as `unknown` in normal CLI mode
- Supports HTTPS, HTTP, and `ssh://` repository URLs
- Uses existing Git credentials, disables interactive prompts, and limits each lookup to 30 seconds
- Reports individual lookup failures while continuing through remaining packages

Reports the newest upstream tag, including versions outside your declared requirements
It does not determine whether an update is compatible, resolve dependencies, rewrite manifests, or modify lockfiles
Registry dependencies and SCP-style SSH URLs such as `git@host:owner/repo.git` are not supported in this initial version
Network lookups run with at most eight requests in flight

## Verification

Built and tested through Xcode's native MCP server using `swift-update-Package` on My Mac
All 20 Swift Testing cases passed, covering semantic versions, lockfile schemas 1–3, branch diagnostics, cache invalidation and expiration, failure retries, and simultaneous checks
Live CLI checks verified release and branch warnings, cross-process cache locking, advisory exit status, and normal JSON failure behavior
