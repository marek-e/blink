# Testing and release

Status: automated tests pass; manual checks below were run on 2026-10-17 on the machine described in the [integration report](integration-report.md). Anything not listed as passed is still open. Don't mark planned checks as passing.

## Automated tests

`swift test --package-path Packages/BlinkCore` runs 59 tests in 9 suites (about 0.01 s). The same tests run through the `Blink` scheme with `xcodebuild test`, in CI, and as x86_64 under Rosetta (`xcodebuild test -destination "platform=macOS,arch=x86_64"`).

| Area | Cases covered | Requirements |
| --- | --- | --- |
| URL intake | HTTP/HTTPS, ports, query and fragment preserved byte for byte, missing host, relative and scheme-less input, credentials, raw controls vs percent-encoded controls, unsupported schemes, delivered files | B01, B13, B16 |
| Host normalization | Case, trailing dot, Unicode and punycode equivalence, IPv4, IPv6, single-label, underscore labels, every rule-input rejection | B05, B13 |
| Rule evaluation | Exact, subdomain opt-in, misleading suffixes, numeric hosts, disabled rules, overlaps, order, no match, shadowing | B05, B17 |
| Request coordinator | FIFO, identical separate requests, cancel only the active request, cancel ignored while dispatching, double selection, stale callbacks, launch failure, explicit retry, another browser after failure, missing browser, per-scheme availability, rule dispatch without picker, no fall-through for unavailable rule destinations, rules read at activation, browser activation only when no links wait, slow dispatches becoming visible and cancellable, pause during welcome, discard at quit | B03, B06, B11 |
| Browser preferences | New browsers appended in name order, non-browsers hidden, never empty, reinstall keeps preferences, picker choices follow order and visibility, last visible browser can't be hidden, reorder | B02, B04 |
| Configuration store | Round trip and documented schema keys, documented example loads, six kinds of invalid file, newer schema preserved, reset backs up, stray temp file ignored, write failure keeps the old file and leaves no temp file, invalid configuration refused | B12 |
| Default browser state | Both schemes, one scheme each way, neither, unknown identity | B07 |
| Picker geometry and keys | Pointer centering, menu bar and Dock avoidance, screen edges, second display with negative coordinates, small screens, fallback screen, key mapping for digits, keypad and modifiers | B03, B10, B14 |

## Manual checks run

Driven through the Accessibility API with synthetic `example.com` URLs, using a scratch configuration file (`scripts/run-debug.sh`).

| Check | Result |
| --- | --- |
| Welcome window, all five steps, VoiceOver labels present | Passed |
| Two links delivered during the welcome window wait and open in order afterwards | Passed |
| Picker shows host, masked preview, "1 more link", browsers in configured order, first row selected | Passed |
| Arrow keys, Escape cancels only the active link, physical number keys dispatch | Passed |
| Rule with subdomains routes without a picker; a later, more specific rule is shadowed and the Rules tab says so | Passed |
| Rule to an uninstalled browser shows the recovery picker, names the browser, doesn't try later rules | Passed |
| Browser reorder and hide persist to disk | Passed |
| Rule editor normalizes input live and saves; rule tester reports the matching rule | Passed |
| Newer-schema settings file: left untouched, temporary defaults, explanation shown; Reset backs it up and writes defaults | Passed |
| Link with credentials from another app is refused with an explanation; the log has no URL | Passed |
| Open Link rejects `example.com`, accepts a full URL and sends it to the picker | Passed |
| Quit with two links waiting asks first; Keep Blink Open keeps both, Discard and Quit exits | Passed |
| Cold launch by a link shows the picker with that link | Passed |
| Local HTML file opens through the picker in Safari | Passed |
| Two queued links: the second picker takes keyboard input without a click; the browser comes forward after the last one | Passed |
| "Always open" saves one rule only after the link opens; the next link to that host skips the picker | Passed |
| Two invalid links in a row produce two alerts, one after the other | Passed |
| A damaged settings file opens Settings › General at launch | Passed |
| Reopening Blink during the welcome window brings the welcome window forward | Passed |
| Settings file and logs contain no URLs after these tests | Passed |
| Set as default: macOS asks once, "Keep Arc" leaves both handlers unchanged and Blink says so; "Use Blink" changes HTTP and HTTPS together and the status updates | Passed |
| A link opened through the system default (as any app does) reaches Blink; during the welcome window it waits and the window counts it | Passed |
| Default changed back to Arc outside Blink; Blink's status follows | Passed |
| Partial assignment | Can't be produced on macOS 26: changing HTTPS alone is refused by both the current API (error 256) and the deprecated one (-54). The state logic has unit tests |
| Picker delivered while another app stays active (`open -g`): arrow keys, numbers and Escape work, and one click dispatches | Passed |
| A browser waiting on Gatekeeper's first-launch prompt: the picker shows "Opening…", the prompt stays above it, and the link opens once the prompt is answered | Passed (Brave, 30.5 s) |
| Light appearance for the picker and Settings (`-BlinkAppearance light`) | Passed |
| Intel build under Rosetta (`X86-64 (translated)`): picker, manual and rule dispatch | Passed |
| Release pipeline dry run (`DEVELOPER_ID_APPLICATION=- SKIP_NOTARIZATION=1`): archive, hardened-runtime signing, verification, DMG with Applications link, zip, checksums | Passed |
| Login item on and off from Settings; the switch follows the status macOS reports (enabled, then not registered) | Passed |
| Login item "requires approval" state | Not run |
| VoiceOver labels, roles and announcements, checked through the accessibility tree | Passed |
| Listening pass with VoiceOver, Increase Contrast, Reduce Motion, multiple physical displays | Not run: the accessibility preferences are protected and only one display is attached. Colors are system colors and motion is gated on Reduce Motion; placement on several displays has unit tests |
| macOS 14.8.7 (Sonoma, arm64 virtual machine): launch, discovery, rule dispatch, picker, Settings and welcome window | Passed. The VM had no accessibility permission, so manual picks weren't driven there |
| A dispatch macOS never answers (Dia stuck behind a quarantine check in the VM): after 10 s the picker shows "Still waiting for Dia" with Cancel | Passed |
| Intel hardware | Not available; the x86_64 slice was run under Rosetta instead |
| macOS 15 | Not run; CI builds and tests on GitHub's macOS 14 and 15 runners |

## Browser matrix

Run on macOS 26.6.2, arm64. "Running" means the browser was open when the link arrived. Every dispatch was accepted by macOS and the browser came to the front.

| Browser | Version | Bundle ID | Discovery | Manual (HTTPS) | Rule (HTTP) | Running | Quit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Arc | 1.168.0 | `company.thebrowser.Browser` | Passed | Passed | Passed | Passed | Passed (macOS 14 VM) |
| Dia | 1.53.0 | `company.thebrowser.dia` | Passed | Passed | Passed | Passed | Passed (macOS 14 VM) |
| Chrome | 155.0.8059.84 | `com.google.Chrome` | Passed | Passed | Passed | Passed | Passed (4.8 s launch) |
| Zen | 1.17.14b | `app.zen-browser.zen` | Passed | Passed | Passed | Passed | Passed (4.1 s launch) |
| Safari | 26.6.2 | `com.apple.Safari` | Passed | Passed | Passed | Passed | Passed (macOS 14 VM) |
| Brave | 1.97.59 | `com.brave.Browser` | Passed | Passed | Passed | Passed | Passed (first launch behind Gatekeeper; then 177 ms) |

Brave was installed with Homebrew for this run and removed afterwards. Arc, Dia and Safari were not quit on the development machine because they held the owner's open sessions. Their quit state was tested on macOS 14.8.7 in a virtual machine (Arc 1.169.0, Dia 1.53.0, and the Safari bundled with macOS 14.8.7): each launched from quit and received its rule-routed link. Cold launches there took about 30 s to be acknowledged because the VM has no GPU.

## Performance

Optimized universal build (`scripts/build-testing.sh`), Apple M2 Pro, macOS 26.6.2, browsers running.

| Measure | Samples | Result | Target |
| --- | --- | --- | --- |
| Warm intake to interactive picker, measured in app | 100 | p50 39 ms, p95 43 ms, max 85 ms | p95 < 150 ms |
| Cold launch to picker, measured from `open` to the window appearing (includes `open` itself) | 20 | p50 418 ms, p95 482 ms, max 499 ms | p95 < 1 s |
| Idle CPU, no requests | 60 s | 0.0% | < 1% |
| Physical footprint, idle | 1 | 22 MB | < 75 MB |
| Dispatch accepted by a running browser | 30+ | 17 to 79 ms | not a target |

Blink logs "Picker interactive N ms after arrival" in the intake category, so these can be re-measured on other hardware.

## Release gates

- [x] Every B01 to B17 criterion has evidence (partial default assignment by unit test only; it can't be produced on macOS 26).
- [x] Minimum OS and architectures checked: macOS 14 in a VM, macOS 26 natively, x86_64 under Rosetta.
- [x] All six required browsers pass discovery, manual selection, domain routing and HTTP/HTTPS dispatch, running and quit.
- [x] No known link-loss, duplicate-dispatch, recursion or silent misrouting bugs.
- [x] Accessibility: labels, roles, announcements and keyboard paths verified; light and dark appearance checked. A listening pass with VoiceOver is still worth doing before a public launch.
- [x] Privacy checks: no URLs in logs or on disk.
- [x] Bundle ID, icon, version 1.0.0 (1) and ownership settled.
- [x] License (proprietary) and name review recorded in [decisions](decisions.md).
- [ ] Signed with the owner's Developer ID and notarized. `scripts/release.sh` and the release workflow were dry-run end to end with ad-hoc signing; they need the owner's certificate and notarization credentials.
- [ ] A downloaded, notarized copy passes Gatekeeper on a clean account (depends on the previous item).
- [x] Installation, default-browser reversal, limitations and uninstall instructions written (README).
- [x] Release notes in `docs/releases/1.0.0.md`; the pipeline writes checksums and the revision.

Updates are manual. Before removing Blink, users should pick another default browser and turn off its login item. Blink never rewrites the default browser on its own. If a release is defective, stop distributing it and republish the last good build. Never downgrade a newer settings schema silently; an older Blink treats a newer file as read-only.
