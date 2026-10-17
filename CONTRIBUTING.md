# Contributing

## Layout

| Path | Contents |
| --- | --- |
| `Packages/BlinkCore` | Swift package with all logic that doesn't need AppKit: URL intake, host normalization, rules, configuration and its atomic store, the request queue, picker geometry and key mapping. Tested with Swift Testing. |
| `Blink/Sources` | The app target: AppKit lifecycle, browser discovery, dispatch, default-browser and login integration, and the SwiftUI picker, settings and welcome views. |
| `Blink/Resources` | `Info.plist`, entitlements (none), and the asset catalog with the generated app icon. |
| `project.yml` | XcodeGen spec. `Blink.xcodeproj` is generated from it and committed. |
| `scripts/` | Build, install, release, icon and debugging helpers. |

## Toolchain

Developed with Xcode 27.1 (Swift 6.4) on macOS 26.6. The code uses the Swift 6 language mode and targets macOS 14. CI selects the newest Xcode on GitHub's `macos-14` and `macos-15` runners (currently Swift 6.0.3 and 6.2.4), so code must also compile with Swift 6.0. Release builds use `macos-15`. XcodeGen 2.46.0 regenerates the project (`brew install xcodegen`).

## Build and test

```sh
swift test --package-path Packages/BlinkCore      # core tests, about a second
xcodebuild -project Blink.xcodeproj -scheme Blink test        # same tests through the shared scheme
xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Release build
```

After adding, removing or renaming files under `Blink/`, run `xcodegen generate` and commit the project. CI fails when the committed project differs from the generated one.

Local builds are ad-hoc signed ("Sign to Run Locally"), so they run only on the Mac that built them.

## Run without touching your settings

```sh
scripts/run-debug.sh [scratch-dir]
```

This builds Debug and launches it with `-BlinkConfigurationPath <scratch>/configuration.json`. Debug builds honor that argument; Release builds ignore it. Send it links with `open -a build/DerivedData/Build/Products/Debug/Blink.app https://example.com`.

`scripts/build-testing.sh` builds an optimized universal copy that accepts the same arguments, for performance runs and for testing the Intel slice with `open --arch x86_64`. Debug and testing builds also accept `-BlinkAppearance light` or `dark`.

Debug builds launched by the script also accept `-BlinkSnapshotDirectory`. `scripts/snap.sh` then makes Blink write PNGs of its visible windows there, which helps review UI without screen-recording permission.

Test default-browser changes in a separate macOS user account or VM, and record the previous handlers first. Don't change your daily setup from automated checks.

## Install for yourself

`scripts/install-local.sh` tests, builds Release, replaces `/Applications/Blink.app` and opens it.

## Release

`scripts/release.sh` archives a Release build signed with your Developer ID and the hardened runtime, notarizes and staples the app and a DMG, and writes `dist/Blink-<version>.dmg`, a zip, `SHA256SUMS.txt` and `REVISION.txt`. It needs:

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export TEAM_ID=TEAMID
xcrun notarytool store-credentials blink-notary --apple-id you@example.com --team-id TEAMID
export NOTARY_PROFILE=blink-notary
scripts/release.sh
```

Set `SKIP_NOTARIZATION=1` for a signing-only run. `DEVELOPER_ID_APPLICATION=- SKIP_NOTARIZATION=1 scripts/release.sh` signs ad-hoc and exercises every step except notarization, without any certificate.

Pushing a tag such as `v1.0.0` runs `.github/workflows/release.yml`, which does the same on GitHub Actions and publishes the DMG, zip and checksums to GitHub Releases with the notes in `docs/releases/<version>.md`. The workflow's header lists the repository secrets it needs. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate, and then follow the checklist in [testing and release](docs/testing-and-release.md).

The bundle identifier is `dev.melmayan.blink`. Don't change it: the settings folder and the default-browser registration follow it, so existing users would lose their settings.

## The app icon

`scripts/generate-icon.sh` renders the icon set from `scripts/IconGenerator` and `Blink/Sources/Support/BlinkGlyph.swift`. The menu bar icon draws the same glyph at runtime, so edit the geometry in one place.

## Before changing code

1. Read [project context](CONTEXT.md), the relevant requirements, and [open decisions](docs/decisions.md).
2. State assumptions and decide how you'll check success.
3. Keep changes scoped. Avoid speculative abstractions and unrelated cleanup.
4. For a bug, reproduce it before fixing it. For logic changes, cover the boundary cases in BlinkCore tests.

Don't commit signing credentials, provisioning assets containing secrets, personal URLs, browser profile files, or local settings.

## Conventions

- Prefer platform frameworks. There are no third-party dependencies; add one only for a demonstrated need.
- Keep routing and validation in BlinkCore, free of AppKit and file access other than the configuration store.
- UI state lives on the main actor. Configuration writes and request transitions happen there too.
- Open links in an explicit application. Never hand a routed link back to the system default handler, which may be Blink.
- Never build a shell command from a URL.
- Never log a URL, host or rule domain. Log the operation and an error domain and code.
- Use synthetic domains such as `example.com` in fixtures and screenshots.

## Definition of done

A change satisfies its requirement IDs, handles its documented errors, and has tests or recorded manual checks. UI work includes keyboard and VoiceOver checks. Update the affected documents and record any departure from a decision. In the PR, describe the checks you ran and what remains unverified.
