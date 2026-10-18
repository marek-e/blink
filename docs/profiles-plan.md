# Browser profiles: implementation plan

Status: implemented, 2026-10-18. Built on the results in the [capability matrix](profiles-capability.md); [ADR 0003](adr/0003-profile-destinations.md) records the decision.

## Where the build differs from this plan

- Arc spaces come from `StorableSidebar.json` alone; their profile directories aren't needed to open a link, so `Local State` isn't read for Arc.
- Settings › Browsers shows a profile count that opens a popover with the checkboxes. A disclosure group doesn't work inside a macOS list row.
- AppleScript runs through `osascript` (step 4's open question). The scripts ask a browser that has no window to `reopen`, because Dia ignored `make new window` and `reopen` worked.
- The Arc script looks for the window that holds the space, because Little Arc windows don't, and Arc's sidebar file lists Little Arc's single space before the main window's.
- The catalog keeps every profile it reads, so a rule to a browser's only profile still opens; the › appears only with two or more.

## What the user gets

- The picker looks the same as today. Choosing a browser row opens the link the way that browser normally does: Arc in its current space, Dia in its current profile, Chrome in the last-used profile.
- A browser with two or more profiles gets a › on its row. Clicking › or pressing → shows its profiles as indented rows under it; ← or clicking › again hides them. Choosing a profile row opens the link in that profile.
- Rules can send a domain to a browser or to one of its profiles ("hublo.com → Arc · Hublo"). "Always open <host> in the chosen browser" saves whichever row was chosen, profile included.
- Settings › Browsers lists each browser's profiles, and each can be hidden from the picker (for example Arc's "Archived" space).
- Supported: Arc (spaces), Dia, Chrome, Brave, Edge, Vivaldi, Chromium, Zen and Firefox. Safari, and any browser Blink doesn't know, stays a single row without ›.

```
  [A] Arc                  ›  1
  [◐] Dia                  ⌄  2
        Personal
        Dev
        Praxis
  [◎] Google Chrome           3
  [S] Safari                  4
```

Number keys 1–9 keep addressing browser rows only, so a browser's number never changes when another browser is expanded. Profile rows are reached with the arrow keys or the pointer.

## Design

### Destination

A new value type in BlinkCore replaces the bare bundle ID wherever a link is sent:

```swift
public struct Destination: Codable, Hashable, Sendable {
    public var bundleID: String
    public var profile: ProfileReference?
}

public struct ProfileReference: Codable, Hashable, Sendable {
    /// Stable across renames: Arc space ID, Chromium profile directory, Firefox profile path.
    public var id: String
    /// Last name seen, for display when the profile is gone.
    public var name: String
}
```

Each browser family has a stable key that survives renames:

| Family | `id` | Resolved at dispatch to |
| --- | --- | --- |
| Arc | Space ID from `StorableSidebar.json` | The same ID, passed to AppleScript |
| Dia | Profile directory (`Profile 1`) | The current name from `Local State`, passed to AppleScript (Dia only targets profiles by name) |
| Chrome, Brave, Edge, Vivaldi, Chromium | Profile directory | `--profile-directory=<id>` |
| Zen, Firefox | Profile path from `profiles.ini` | `-P <current name>` |

`RequestPhase.dispatching`, `RequestFailure`, `RequestOutcome.opened`, `RoutingDecision.matched` and `RequestCoordinator.choose` take a `Destination` instead of a bundle ID. `BrowserLocating` keeps answering per bundle ID; whether a profile still exists is checked by the opener, at dispatch time like the browser itself.

### Configuration, schema version 2

- `Rule.destinationBundleID` becomes `Rule.destination`. Decoding a version 1 file maps `destinationBundleID` to a destination without a profile, and the next save writes version 2.
- `BrowserPreference` gains `hiddenProfileIDs: [String]`, empty when missing.
- `validate()` rejects an empty profile ID.
- An older Blink that finds a version 2 file reports "written by a newer Blink" and leaves it untouched (B12 already does this), so going back to 1.1 loses profile rules until the user upgrades again. The release notes must say so.

This is hard to reverse once released, so it gets an ADR (`docs/adr/0003-profile-destinations.md`) before the code.

### Finding profiles

A `ProfileCatalog` in the app target, next to `BrowserCatalog`, lists profiles per installed browser. File parsing lives in BlinkCore as pure functions over `Data`, so it's tested with fixture files:

- `ArcSidebar.spaces(sidebar:localState:)`: spaces with their profile directory and display name.
- `ChromiumLocalState.profiles(_:)`: directories and names from `profile.info_cache`, skipping Arc's `__ARC_SYSTEM_PROFILE`.
- `FirefoxProfiles.profiles(ini:)`: `[ProfileN]` sections. A profile that has never been opened (no `prefs.js`) is skipped, so Zen's unused `default` doesn't show.

Where to look is a table keyed by bundle ID (Chrome → `Google/Chrome`, Brave → `BraveSoftware/Brave-Browser`, Zen → `zen`, ...). Unknown bundle IDs get no profiles.

The catalog reads the files when the picker is about to show (B02 already refreshes browsers there), and skips files whose modification date hasn't changed. Any read or parse error means "no profiles" for that browser, logged without paths or names. The picker never waits on this: if a read is slow the row simply has no › for that request.

### Sending a link

`LinkOpening.open` takes a `Destination`. `WorkspaceOpener` picks one of three ways:

1. **No profile**: today's `NSWorkspace.open(_:withApplicationAt:configuration:)`, unchanged.
2. **Launch arguments** (Chromium family, Zen, Firefox): `NSWorkspace.openApplication(at:configuration:)` with `createsNewApplicationInstance = true` and `arguments = [flag, value, url]`. The new process hands the link to the running browser and exits, or starts the browser when it's quit. The URL is passed as its own argument, never through a shell.
3. **AppleScript** (Arc, Dia): the scripts from the capability matrix, compiled once and run with the space ID or profile name and URL as parameters (`on run {…}`), never by building script text from the URL. They wait up to 10 seconds for a window. The existing slow-dispatch banner covers a long cold start.

The AppleScript must not block the main thread, because a cold start takes 3–4 seconds. Two options, settled in step 4: `NSAppleScript` on a dedicated serial queue, or `/usr/bin/osascript` as a child process. The second is simpler to keep off the main thread; it has to be checked that macOS's Automation prompt then names Blink, not osascript.

### Failures

Two new `RequestFailure` cases, shown in the picker's existing banner with no silent fallback (B06):

- `profileUnavailable`: the space or profile is gone. Actions: "Open in <browser>" (without the profile, as an explicit choice), choose another row, or "Edit Rules" when a rule sent it there.
- `automationDenied`: macOS refused Apple Events (error -1743). Actions: "Open Privacy Settings" (Automation pane) and "Open in <browser>" without the profile.

The Rules tab (B17) also warns about rules whose profile no longer exists.

### Permissions and entitlements

- `NSAppleEventsUsageDescription` in `Info.plist`: "Blink asks Arc and Dia to open links in the space or profile you choose."
- `com.apple.security.automation.apple-events` in `Blink.entitlements`, required with the hardened runtime. This replaces the "no entitlements" entry in the [decision register](decisions.md).
- macOS asks once per browser, the first time a link goes to an Arc space or Dia profile. Nothing asks before that, so people who never use profiles never see a prompt.

### Privacy

Blink starts reading other apps' files. It reads only profile lists (`Local State`, `StorableSidebar.json`, `profiles.ini`), keeps only profile IDs and names, and never reads history, cookies or tabs. CONTEXT.md and the architecture document currently say Blink doesn't inspect browser profiles; both change. Logs never contain profile names (B09).

## Steps

Each step builds, passes tests, and leaves the app shippable.

1. **Model and migration.** ADR 0003. `Destination`, `ProfileReference`, schema version 2 with migration, coordinator and rule changes. No visible change. Tests: decoding version 1 files, round-tripping version 2, rule evaluation and coordinator transitions with profiles.
2. **Profile discovery.** The three parsers with fixture tests, `ProfileCatalog`, the location table. Fixtures are made-up files in the real formats, not copies from a real Mac.
3. **Launch-argument dispatch.** Chromium and Firefox families through `openApplication`. Test with Chrome (needs a second profile) and Zen, running and quit.
4. **AppleScript dispatch.** Arc and Dia, entitlement, usage description, `automationDenied` and `profileUnavailable`. Test the permission prompt, a refusal, a deleted space and a renamed Dia profile.
5. **Picker.** A flat list of visible rows (browsers plus expanded profiles) drives selection, so `PickerSession.selection`, the arrow keys and VoiceOver work as now; → and ← expand and collapse; the › button; "Always open" with profiles. Check light and dark mode, VoiceOver ("Arc, collapsed, 6 profiles"), and the list scrolling when expanded on a small screen.
6. **Settings.** Profiles under each browser in Settings › Browsers with visibility toggles; the rule editor's "Open in" lists profiles under their browser, keeping a missing one selectable as "(not found)" like a missing browser today.
7. **Docs and release.** Product requirement B19, architecture, CONTEXT.md, interaction design, decision register, README, release notes (including the downgrade note). Re-run the whole capability matrix on the release build, signed or ad hoc as the release will be.

Steps 2–4 can be built in parallel once step 1 is merged. Step 5 needs 2; step 6 needs 5.

## Still open

- Chrome with a second profile while running: the one case not yet tested. Brave, Edge, Vivaldi and Firefox weren't installed.
- Arc or Dia running with no window, end to end: the `reopen` fallback was checked by hand on Dia only.
- Whether `osascript` or `NSAppleScript` is used (step 4).
- Whether a browser should remember being expanded between links. This plan resets it for every link, like the rest of the picker; that can change after using it.
