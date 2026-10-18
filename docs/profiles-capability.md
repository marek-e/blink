# Browser profiles: capability matrix

Started 2026-10-18 for the "after the MVP" profile evaluation in the [build plan](build-plan.md). Each browser needs its own proof, both while running and while quit, before Blink claims profile support for it.

| Browser | How to target a profile | Running | Quit | Running, no window |
| --- | --- | --- | --- | --- |
| Arc 1.168.0 | AppleScript: open a tab in a space; each space belongs to one profile | Works | Works, after waiting for a window | Not tested |
| Chrome, Brave, Edge, Vivaldi | `--profile-directory=<dir>` on a new instance, which hands off to the running one | Not tested | Not tested | n/a |
| Firefox, Zen | `-P <name>` | Not tested | Not tested | n/a |
| Safari | No public way | n/a | n/a | n/a |
| Dia | Unknown | Not tested | Not tested | Not tested |

## Arc

Arc has no launch flag for profiles. Profiles belong to spaces: every space uses one profile, and several spaces can share one. Opening a tab in a space opens it in that space's profile.

### Listing spaces and profiles

Arc's scripting dictionary has spaces (`id`, `title`, `tabs`, `focus`) but no profile property. The mapping comes from Arc's files in `~/Library/Application Support/Arc/`:

- `StorableSidebar.json`: `sidebar.containers[].spaces[]` holds each space's `id`, `title` and `profile`. `profile` is `{"default": true}` or `{"custom": {"_0": {"directoryBasename": "Profile 2", ...}}}`.
- `User Data/Local State`: `profile.info_cache` maps each directory (`Default`, `Profile 2`) to its display name. Arc keeps an internal `__ARC_SYSTEM_PROFILE` there that no space uses.

These are undocumented formats. Blink must treat a missing or unreadable file as "no profiles" and fall back to opening Arc normally.

### Opening a link in a space

```applescript
on run {spaceID, theURL}
	tell application "Arc"
		repeat 50 times
			if (count of windows) > 0 then exit repeat
			delay 0.2
		end repeat
		if (count of windows) = 0 then make new window
		tell front window
			tell space id spaceID
				make new tab with properties {URL:theURL}
				focus
			end tell
		end tell
		activate
	end tell
end run
```

Targeting the space by `id` keeps working when the space is renamed.

### Results

| State | Result | Time |
| --- | --- | --- |
| Running, window open | Tab opens in the space, and Arc switches to it | 0.3–0.4 s |
| Quit, without the wait loop | Fails: `Can't get window 1` (-1719). Arc launches, but has no window yet when the command arrives | 7.5 s |
| Quit, with the wait loop | Tab opens in the space | 3.0 s |
| Running, no window | Not tested. The `make new window` fallback is unproven | |

Reading `URL of active tab` right after `make new tab` can return an empty string while the page starts loading.

### What it costs Blink

- Apple Events: macOS asks once for permission for Blink to control Arc. If the user declines, Blink must report it rather than silently opening Arc's current space.
- `NSAppleEventsUsageDescription` in `Info.plist`, and the `com.apple.security.automation.apple-events` entitlement for hardened-runtime builds. This ends the "no entitlements" decision in the [decision register](decisions.md).
- Reading Arc's files from `~/Library/Application Support`. On the first attempt during this test, reading the folder hung for two minutes, apparently on a pending privacy prompt; later attempts were immediate.
- The Browser Company stopped adding features to Arc in 2025 to work on Dia. Arc's files and scripting are unlikely to change, but a future update or a move off Arc would make this code dead weight.
