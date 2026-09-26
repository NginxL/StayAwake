# Development

English · [简体中文](DEVELOPMENT.zh-CN.md) · [Back to README](../README.md)

StayAwake is a Swift Package Manager project with a SwiftUI interface and an AppKit menu bar entry. The application uses macOS's built-in `caffeinate` utility and has no third-party package dependencies.

## Requirements and local build

Use macOS 14 or later with Swift 5.9 or later. Apple Command Line Tools are sufficient; a full Xcode installation is not required.

```bash
xcode-select --install # Skip if Command Line Tools are already installed.
git clone https://github.com/NginxL/StayAwake.git
cd StayAwake
bash scripts/build.sh
```

The build script compiles for the host architecture, creates `dist/StayAwake.app`, generates the icon, bundles the update helper and license files, and signs the app. Open the app in Finder. For daily use or login-item registration, move it to a stable location in `/Applications` or `~/Applications` first.

Build and package both supported architectures:

```bash
bash scripts/package.sh --universal
```

This produces `dist/StayAwake.app`, `dist/StayAwake-<version>-universal.zip`, and a matching `.zip.sha256` file. The universal executable includes `arm64` and `x86_64`.

Builds use an **ad-hoc signature by default** and are **not notarized**. Setting `CODESIGN_IDENTITY` changes the signing identity used by the build script; it does not perform notarization. A SHA-256 checksum or valid ad-hoc signature does not authenticate an Apple Developer ID publisher. The scripts do not change Gatekeeper or other system security settings.

## Tests

```bash
bash scripts/test.sh
```

Tests run through the `AwakeChecks` executable, using an injected clock and fake process driver. Use this script rather than `swift test`: the package does not define an XCTest test target. Core checks cover session expiry, duration changes, display-mode changes, failed starts, unexpected process exit, time formatting, version comparison, and menu bar anchor selection across displays.

Optional macOS integration checks:

```bash
bash scripts/test.sh --integration
```

These checks briefly create **real sleep-prevention assertions** and inspect them with `pmset -g assertions`. They verify display control, timeout and stop behavior, and assertion release after force-terminating a dedicated test process. They do not force-quit the installed app.

Before a release, also verify the actual panel, menu bar interaction, Dock entry, login-item setting, and update flow. The core test runner does not automate those UI and installation paths.

For multiple displays, open the panel from each menu bar, then switch displays while it is open. Verify that it follows the clicked icon, closes when clicked again on the same display, and remains usable after rearranging or disconnecting a display. Include displays with different scaling and vertical arrangements.

## Implementation

| Component | Responsibility |
| --- | --- |
| `Sources/AwakeCore/` | Session state, deadlines, time formatting, version comparison, and the `caffeinate` driver |
| `Sources/StayAwake/` | SwiftUI panel, AppKit menu bar and Dock behavior, saved preferences, login items, and updates |
| `Tests/AwakeCoreTests/` | Standalone core checks and optional integration checks |
| `Resources/` | App metadata and the update-installation helper |
| `scripts/` | Build, test, package, and icon-generation scripts |
| `.github/workflows/` | CI builds and tagged releases |

`CaffeinateConfiguration` constructs the arguments for `/usr/bin/caffeinate`:

| Argument | Purpose |
| --- | --- |
| `-i` | Prevent idle system sleep |
| `-d` | Optionally prevent idle display sleep |
| `-t <seconds>` | Limit a timed session |
| `-w <app PID>` | Release the assertions when the owning application exits, including force quit |

`SessionController` tracks the deadline and refreshes it after the Mac wakes. Changing the duration starts a new countdown; changing display mode preserves the current deadline. The driver starts a replacement process before terminating the previous one, so a failed launch can leave the existing session intact. The app always starts with sleep prevention disabled.

The app does not modify `pmset` configuration, override explicit sleep commands, or guarantee operation with a closed laptop lid.

`MenuBarAnchor` selects a display from the pointer position captured before application activation. The panel uses the status button when its window is on that display; otherwise, a temporary transparent window anchors the mirrored menu bar click to the correct screen. Closing the panel releases that window. Changes to display configuration close the panel so the next click uses fresh geometry. All placement calculations use screen points, including negative display origins.

## Update implementation

Update checks and installation are initiated by the user. `AppUpdater` reads the latest published release from `NginxL/StayAwake`, compares its three-part version, and expects these assets:

```text
StayAwake-<version>-universal.zip
StayAwake-<version>-universal.zip.sha256
```

The updater validates the asset location, checksum, bundle identifier, version, executable presence, and code-signature integrity before staging the app. Installation requires a writable `/Applications` or `~/Applications` directory. The helper waits for the running app to exit, replaces it, and launches the replacement; the active sleep-prevention session ends during this process.

The previous app is retained beside the installation as `.StayAwake-previous.app`. If replacement fails or the launch command returns an error, the helper attempts to restore it. **There is no post-launch health check or automatic rollback on a later crash.** Download or validation failures occur before replacement and leave the installed app in place.

## Publishing a release

1. Set `CFBundleShortVersionString` in `Resources/Info.plist` to the next `major.minor.patch` version, and increment `CFBundleVersion`.
2. Run `bash scripts/test.sh --integration` and `bash scripts/package.sh --universal`; complete the UI and update checks described above.
3. Commit the release changes to `main`, then create and push the matching tag. For example, version `1.0.1` requires tag `v1.0.1`.
4. Verify the **Publish Release** workflow and confirm that both the ZIP and checksum are attached to the published GitHub Release.

[Build macOS App](../.github/workflows/build.yml) runs the core checks and packages a universal app on pushes to `main`, pull requests, and manual dispatch. Its downloadable workflow artifacts are separate from GitHub Release assets.

[Publish Release](../.github/workflows/release.yml) runs on `v*` tags or manual dispatch with an existing tag. It verifies the tag against `CFBundleShortVersionString`, runs core checks, builds the universal package, and creates the release with its assets. If that release already exists, the workflow preserves its assets and skips publication.

**Pushing source code or producing a CI artifact does not make an update available to installed clients.** A newer published release must include both correctly named assets. The current updater accepts numeric three-part versions, optionally prefixed with `v`; prerelease suffixes are not supported.
