# Decisions and open questions

Updated: 2026-10-17. "Proposed" means a working assumption without user approval. "Verified" means the [integration report](integration-report.md) or tests back it.

## Confirmed

| Decision | Basis |
| --- | --- |
| Blink; "From link to browser, instantly." | User selection in the shared conversation |
| Native macOS browser picker and intelligent link router | Product direction in that conversation |
| Minimal, premium, fast visual direction | Product identity described there |
| Arc, Dia, Chrome, Zen, Safari, and Brave compatibility | Explicit user requirement after the naming conversation |

## Settled by implementation

| Decision | Evidence | Record |
| --- | --- | --- |
| Swift, SwiftUI and AppKit in one app, logic in a local package | Built and tested | [ADR 0001](adr/0001-native-local-app.md), accepted |
| macOS 14 deployment target, universal binary | Ran on macOS 14.8.7 in a VM and as x86_64 under Rosetta | Integration report |
| Not sandboxed; Developer ID, hardened runtime, Apple Events entitlement only | Opening links in Arc spaces and Dia profiles needs Apple Events; nothing else needs an entitlement | Integration report, [ADR 0003](adr/0003-profile-destinations.md) |
| Manual picker plus ordered host rules, first match wins | Tests and manual routing checks | [ADR 0002](adr/0002-explicit-routing.md), accepted |
| Host normalization through `URLComponents.encodedHost` plus lowercasing and one trailing dot | Tests for Unicode, punycode, case, dots, IPs | Integration report |
| Developed with Xcode 27.1 (Swift 6.4); CI builds with the newest Xcode on each runner (Xcode 16.2 and Swift 6.0.3 on `macos-14`, Xcode 26.3 and Swift 6.2.4 on `macos-15`); XcodeGen 2.46.0 pinned | CONTRIBUTING and CI. The code must build with Swift 6.0, the oldest toolchain CI uses | |
| Apps that don't open HTML documents start hidden | Separated browsers from ChatGPT and cmux on the test machine | [Product](product.md) |
| Picker shortcuts use physical key codes | Required for AZERTY | Product B14 |
| Local HTML files handed over by macOS are routed through the picker | Default browsers receive them | Product B16 |
| Yield activation to the browser on dispatch | Without it Blink stayed frontmost | Integration report |
| Destinations can name a profile; schema version 2 | Arc, Dia, Chrome and Zen tested running and quit | [ADR 0003](adr/0003-profile-destinations.md), [capability matrix](profiles-capability.md) |
| Rules can match a path prefix, segment by segment; schema version 3 | Tests | [ADR 0004](adr/0004-rule-path-prefixes.md) |
| No URL history or telemetry | Logs audited | Architecture |
| Manual updates | No updater shipped | Release plan |
| Original icon (forked-path mark) | `scripts/IconGenerator` | |

## Settled for release

| Decision | Basis |
| --- | --- |
| Bundle ID `dev.melmayan.blink` | The owner's handle, matching the Git identity. Settings live under this name, so changing it later would orphan users' settings |
| Open source under the MIT License | Owner's choice on 2026-10-18, replacing the earlier proprietary decision. MIT is short and permissive, and fits a small utility that others may fork or package |
| Name "Blink" kept | A 2026-10-18 search found no browser picker or link router called Blink. The name is crowded elsewhere (Chromium's engine, Amazon's cameras, several unrelated Mac apps), so App Store search would be noisy. This is not legal clearance |
| Releases on GitHub Releases for `marek-e/blink`, support through GitHub issues | The repository is already there; `.github/workflows/release.yml` publishes tagged builds |
| Unsigned releases until a Developer ID exists; signed automatically once the secrets are added | The Apple Developer Program costs $99 a year. Ad-hoc builds run after a one-time Open Anyway |
| Homebrew through this repository as a tap (`Casks/blink.rb`) | The official cask catalog requires notarized apps |
| English only for 1.0 | Small UI; localization can follow demand |

## Still open

| Question | Current state | Resolve by |
| --- | --- | --- |
| Developer ID certificate and notarization credentials | Only the owner can enroll in the Apple Developer Program ($99 a year). Until then, releases are unsigned and need Open Anyway once | Optional; removes the first-launch block |

## Decision process

Use an ADR for choices that are expensive to reverse. Include status, context, decision, consequences and verification. Mark superseded decisions and link replacements. When scope changes, update the requirements, architecture, test plan and build plan together.
