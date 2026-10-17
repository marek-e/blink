# Testing and release

Status: planned checks. No application or automated tests exist yet. Record commands and results here as implementation milestones complete; do not mark planned checks as passing.

## Automated coverage

| Area | Required cases | Requirements |
| --- | --- | --- |
| URL intake | HTTP/HTTPS, ports, query/fragment preservation, missing host, relative URL, credentials, controls, unsupported schemes | B01, B13 |
| Host normalization | Case, trailing dot, Unicode/punycode equivalence, IPv4/IPv6, single-label host, invalid rule input | B05, B13 |
| Rule evaluation | Exact match, subdomain opt-in, misleading suffix, disabled rule, overlapping rules, reorder, no match, unavailable first match | B05, B06 |
| Request coordinator | FIFO, identical separate requests, cancel, double selection, stale callbacks, failed dispatch, explicit retry | B03, B06, B11 |
| Browser catalog | Exclude self, missing install, duplicate bundle identity, per-scheme eligibility, ordering, hidden/new/reinstalled browsers | B02, B04 |
| Configuration | Round-trip, invalid JSON, invalid domain/IDs, unsupported version, interrupted write, write failure, explicit reset backup | B12 |
| Rule/UI integration | Edit/reorder persists; failed save rolls back; hidden rule target still works | B04, B05, B12 |

Use fake catalog/opener/storage boundaries to test failures without changing the developer's defaults. Use synthetic URLs, including `https://example.com/path?token=test#fragment`, and verify dispatch receives equivalent intact URL components. Never copy personal links into fixtures.

## Manual integration matrix

Test on the minimum supported macOS version and the latest stable version at release. Record exact OS, CPU architecture, app build, and browser versions. Check Apple silicon and Intel before advertising both. Test Arc, Dia, Chrome, Zen, Safari, and Brave independently, running and fully quit. A result for one browser cannot stand in for another.

For each browser, record its version, resolved bundle ID, OS/architecture, and evidence for discovery, manual selection, domain-rule routing, and intact HTTP/HTTPS dispatch. Run both dispatch paths in both browser states. The table below is a tracking template; all results are currently unverified.

| Required browser | Discovery | Manual selection | Domain rules | HTTP/HTTPS, running and quit |
| --- | --- | --- | --- | --- |
| Arc | Pending | Pending | Pending | Pending |
| Dia | Pending | Pending | Pending | Pending |
| Chrome | Pending | Pending | Pending | Pending |
| Zen | Pending | Pending | Pending | Pending |
| Safari | Pending | Pending | Pending | Pending |
| Brave | Pending | Pending | Pending | Pending |

If a browser is unavailable on a proposed OS/architecture combination, record the limitation and resolve the supported platform scope explicitly before release. Do not mark an untested combination as passing.

- Deliver links from at least two unrelated apps and from Open Link; test cold and warm Blink launches.
- Verify HTTP and HTTPS default assignment, refusal, partial assignment, and changes made outside Blink.
- Confirm the default assignment flow does not silently change any unrelated scheme handler.
- Send multiple links while choosing and while dispatching. Confirm order, duplicate-click protection, repeated identical requests, and per-request cancellation.
- Uninstall or move a selected browser before dispatch; simulate launch failure and verify no automatic fallback.
- Verify no-browser and all-saved-browsers-missing states, refresh, and copy/cancel recovery.
- Test first-launch URL retention, login launch, foreground activation, focus loss, multiple displays, and quitting with pending requests.
- Complete every picker/settings operation using only the keyboard. Check VoiceOver labels, focus order, errors, and queue announcements.
- Check light/dark appearance, increased contrast, reduced motion, long labels, and long URLs.
- Inspect logs and app storage after opening sensitive synthetic URLs. No request URLs or host history should persist.
- Confirm that successful dispatch is not presented as proof that a page loaded successfully.

Test default changes in a dedicated account or VM, record previous handlers, and restore them after testing. Do not modify the user's daily browser setup as part of automated tests.

## Performance measurement

Measure from app intake to an interactive picker; separately measure dispatch initiation to OS completion. Record at least 100 warm and 20 cold samples with hardware, OS, build configuration, and browser state. Report p50 and p95 plus peak/idle memory. Measure idle CPU over 60 seconds with no pending requests. Compare against [product targets](product.md), and document regressions rather than hiding them behind average values.

## Release gates

- [ ] Every B01–B13 acceptance criterion has test evidence.
- [ ] Minimum OS, architectures, and supported browsers match the verified matrix.
- [ ] All six required browsers pass discovery, manual selection, domain routing, and HTTP/HTTPS dispatch checks while running and fully quit.
- [ ] No unresolved link-loss, duplicate-dispatch, recursion, or silent misrouting bugs.
- [ ] Accessibility and privacy checks pass.
- [ ] Bundle ID, app icon, version/build numbers, and product ownership are settled.
- [ ] License and distribution terms are selected; name-conflict review is resolved for public launch.
- [ ] Release is signed with the appropriate Developer ID identity and Hardened Runtime is enabled.
- [ ] Notarization succeeds; ticket is stapled and validated on the final distributed artifact.
- [ ] A freshly downloaded copy passes Gatekeeper and opens links on a clean user account.
- [ ] Installation, default-browser setup/reversal, known limitations, and uninstall instructions are included.
- [ ] Release notes identify tested versions and changes; artifact checksum and build revision are recorded.

Use the verified Xcode distribution flow or Apple's current `notarytool`/`stapler` workflow. Keep certificates, credentials, and signing secrets outside the repo and ordinary CI logs. [Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) is the release reference.

The MVP uses manual updates. Before removing Blink, users should choose another default browser and disable its login item. Do not automatically rewrite defaults during an upgrade. If a release is defective, stop distributing it, publish the known-good build, and explain any configuration compatibility limits. Never downgrade a newer settings schema silently.
