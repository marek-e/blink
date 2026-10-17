# Product requirements

Status: implemented, 2026-10-17. The identity, broad product direction, and required browser targets are confirmed; see [context](../CONTEXT.md). Evidence for each requirement is tracked in [testing and release](testing-and-release.md).

## Problem and audience

People who use multiple browsers need links from mail, chat, documents, and other apps to open in the right place. A single system default cannot express that choice. Blink should make a manual choice quick and a repeated choice predictable.

The initial audience is macOS users who separate work and personal browsing, developers testing multiple browsers, and people with a few sites that belong in a particular browser. Profile-level separation is a future capability, not an MVP promise.

## Core journeys

1. A user clicks a web link in another app. macOS delivers it to Blink. Blink shows a picker; the user selects Safari; Blink sends that link to Safari.
2. A user adds a rule for `example.com` to open in Zen. Future matching requests route there without displaying the picker.
3. A rule's browser has been removed. Blink explains the missing destination and offers available alternatives without silently changing the rule.

Blink only handles requests delivered to it. Links navigated inside a browser, apps that force their own browser, and embedded web views may bypass the system default.

## MVP requirements

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| B01 | Receive web links | Valid HTTP/HTTPS requests work on both cold launch and while running. Each delivered request is tracked independently. |
| B02 | Discover browsers | Discover registered web handlers, exclude Blink, show names and icons, and refresh at launch, before presenting choices, and on explicit refresh. Validate availability again before dispatch. |
| B03 | Choose manually | With no matching rule, show the picker even if only one browser is visible. Click or keyboard selection dispatches once. Escape cancels the active request. |
| B04 | Customize choices | Users can reorder and hide picker browsers. Persist changes. Prevent hiding the last available visible browser; externally missing browsers may still cause an empty state. |
| B05 | Route by domain | Users can add, edit, enable, disable, reorder, and delete rules. First enabled matching rule wins. Exact host is the default; including subdomains is explicit. |
| B06 | Explain failures | Missing destination or launch failure retains the request and offers retry, another browser, copy, or cancel. No silent fallback and no automatic retry loop. |
| B07 | Set up system integration | Explain the default-browser role, request change only after a click, and verify HTTP and HTTPS handlers afterward. Cancellation does not block settings or test-open use. |
| B08 | Operate from menu bar | Menu provides Settings, Open Link, and Quit. Login launch is opt-in and reflects actual service status. |
| B09 | Preserve privacy | No URL history, analytics, accounts, remote rule processing, or background URL requests. Logs exclude hosts and full URLs. |
| B10 | Remain accessible | Picker and settings support keyboard-only operation, VoiceOver, light/dark appearance, increased contrast, and reduced motion. |
| B11 | Queue requests | Process multiple delivered URLs in order, one active request at a time. Cancel affects only the current request. Repeated identical URLs remain distinct requests. |
| B12 | Persist safely | Store versioned local configuration atomically. Invalid or newer unsupported data is preserved and reported, never silently overwritten. |
| B13 | Preserve link meaning | Send the original accepted URL without intentional query, fragment, path, or redirect changes. Reject unsupported schemes and malformed web URLs. |

## Additions after the MVP baseline

Added during implementation, each because the MVP was worse without it.

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| B14 | Number shortcuts | Keys 1 to 9 open the matching picker row on any keyboard layout and on the keypad. Command, Option and Control combinations are ignored. |
| B15 | Rule from the picker | An unchecked "Always open <host> in the chosen browser" checkbox appears for web links that matched no rule. When checked, choosing a browser opens the link and, once macOS accepts it, saves an exact rule for the host (updating an existing exact rule rather than adding a duplicate). It never appears in recovery or read-only states. |
| B16 | Local HTML files | A local file delivered by macOS (because Blink is the default browser) shows the picker with the file name and opens in the chosen browser. Rules never apply to files. Typed links can't be files. |
| B17 | Explain rules | The Rules tab warns about rules made unreachable by earlier ones and about rules whose browser isn't installed. A test field shows which rule, if any, a URL would use, without opening it. |

Discovery also differs from the baseline: an app that registers for web links but not for HTML documents starts hidden in the picker instead of visible, unless that would leave no browser visible. Chat clients and terminals register for links without being browsers.

Opening success means macOS accepted the dispatch to the selected app. Blink cannot guarantee network success or page rendering inside that browser.

## Scope boundaries

The MVP has no browser profile selection, private-window launching, source-app rules, path or regex rules, tracking removal, shortened-link expansion, extensions, sync, accounts, AI service, plugin system, global shortcuts, automatic updater, or monetization flow. It does not replace in-browser navigation.

Arc, Dia, Chrome, Zen, Safari, and Brave are required MVP compatibility targets, explicitly selected by the user. Each must support discovery, manual selection, domain-rule routing, and intact HTTP/HTTPS dispatch, both already running and fully quit. All six pass on macOS 26; see [testing and release](testing-and-release.md).

Test Zen as its own application; a Firefox test does not establish Zen compatibility. Likewise, no browser's passing result substitutes for another's. Other registered HTTP/HTTPS handlers, including Firefox, may appear but are not required release targets and should not be marketed as verified until tested.

Launching a browser uses that browser's own default session/profile behavior. Selecting specific profiles, spaces, or containers remains outside the MVP.

## Quality targets

Local benchmarks on recorded reference hardware: warm request-to-interactive-picker p95 under 150 ms, cold request-to-picker p95 under 1 second, idle CPU below 1% averaged over 60 seconds with no requests, and idle memory below 75 MB. Browser startup and page loading are excluded. All four are met on an M2 Pro: warm p95 43 ms (100 samples), cold p95 482 ms (20 samples), 0.0% idle CPU over 60 seconds and a 22 MB footprint. See [testing and release](testing-and-release.md#performance).

Release requires all MVP acceptance criteria, no known URL-loss or duplicate-dispatch defects in the test matrix, and completed keyboard and VoiceOver checks. Product usefulness should be assessed through explicit tester feedback, without adding telemetry to the MVP.

## Feature inspiration

User-provided references to consult when exploring features or revisiting scope:

- [AltBrowse](https://privdev.com/altbrowse/)
- [Choosy](https://choosy.app/)
- [Velja](https://sindresorhus.com/velja)

Their feature lists were not reviewed in detail. Document any further addition with acceptance criteria before changing scope.
