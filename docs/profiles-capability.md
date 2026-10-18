# Browser profiles: capability matrix

Started 2026-10-18 for the "after the MVP" profile evaluation in the [build plan](build-plan.md). Each browser needs its own proof, both while running and while quit, before Blink claims profile support for it.

| Browser | How to target a profile | Running, same profile | Running, other profile | Quit |
| --- | --- | --- | --- | --- |
| Arc 1.168.0 | AppleScript: open a tab in a space; each space belongs to one profile | Works | Works | Works, after waiting for a window |
| Dia 1.53.0 | AppleScript: open a tab in a profile, by name | Works | Works | Works, after waiting for a window |
| Chrome 155 | `--profile-directory=<dir>` on a new instance, which hands the link to the running one and exits | Works | Not tested (one profile on the test Mac) | Works |
| Zen 1.17.14b | `-P <name>` on a new instance | Works | Works; starts a second Zen process for that profile | Works |
| Safari | No public way | n/a | n/a | n/a |

Brave, Edge and Vivaldi use the same command line as Chrome but weren't installed on the test Mac. Firefox uses the same command line as Zen and wasn't tested either.

"Open a new instance" means `open -n -a <app> --args …`, or `NSWorkspace.openApplication` with `createsNewApplicationInstance` and `arguments`. Without a new instance, macOS ignores the arguments when the browser is already running.

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
| Running, no window | Not tested end to end. Blink sends `reopen` instead of `make new window` | |

Reading `URL of active tab` right after `make new tab` can return an empty string while the page starts loading.

Found while building the feature:

- Arc doesn't support `exists` on spaces (-1708). The app's script checks `(id of spaces of candidate) contains spaceID` instead.
- When a link opens in Little Arc, `StorableSidebar.json` gains a `littleBrowser` container with one untitled space, listed before the main window's. The main window's spaces follow the `global` key.
- A browser that's running with no window gets `reopen`, which opens one. Dia created a window this way; `make new window` returned without error and created nothing.

### What it costs Blink

- Apple Events: macOS asks once for permission for Blink to control Arc. If the user declines, Blink must report it rather than silently opening Arc's current space.
- `NSAppleEventsUsageDescription` in `Info.plist`, and the `com.apple.security.automation.apple-events` entitlement for hardened-runtime builds. This ends the "no entitlements" decision in the [decision register](decisions.md).
- Reading Arc's files from `~/Library/Application Support`. On the first attempt during this test, reading the folder hung for two minutes, apparently on a pending privacy prompt; later attempts were immediate.
- The Browser Company stopped adding features to Arc in 2025 to work on Dia. Arc's files and scripting are unlikely to change, but a future update or a move off Arc would make this code dead weight.

## Dia

Dia's scripting dictionary has a `profile` class ("a space of tabs") with `name`, `index` and `tabs`, reached through a window: `profiles of front window`. Asking the application directly for `profiles` fails (-1728). Profiles have no id, so the script targets them by name.

```applescript
on run {profileName, theURL}
	tell application "Dia"
		repeat 50 times
			if (count of windows) > 0 then exit repeat
			delay 0.2
		end repeat
		tell front window
			set p to profile profileName
			tell p to make new tab with properties {URL:theURL}
			focus p
		end tell
		activate
	end tell
end run
```

| State | Result | Time |
| --- | --- | --- |
| Running | Tab opens in the profile, and Dia switches to it | 0.3 s |
| Quit | Tab opens in the profile | 4.3 s |

To survive renames, Blink should store the profile's directory and look up its current name at dispatch time. Dia is Chromium-based: `~/Library/Application Support/Dia/User Data/Local State` maps directories to names (`Default` → Personal, `Profile 1` → Dev). Whether Dia accepts `--profile-directory` like Chrome wasn't tested; AppleScript worked, so it wasn't needed.

## Chrome family

`~/Library/Application Support/Google/Chrome/Local State` lists profiles in `profile.info_cache`, keyed by directory (`Default`, `Profile 1`) with the display name in `name`. Brave (`BraveSoftware/Brave-Browser`), Edge (`Microsoft Edge`) and Vivaldi (`Vivaldi`) use the same file.

| State | Result |
| --- | --- |
| Quit | Chrome starts in the profile and opens the link |
| Running, same profile | The new process hands the link to the running Chrome and exits; the tab opens in the existing window |

No Apple Events and no extra permission: Blink only adds launch arguments. If a profile directory doesn't exist, Chrome creates it, so Blink must only pass directories it read from `Local State`.

A first attempt used Google Chrome for Testing. It never opened a window, apparently stuck at first-run setup, and the extra processes didn't exit. It isn't a useful stand-in for Chrome.

## Zen and Firefox

`~/Library/Application Support/zen/profiles.ini` (Firefox: `Firefox/profiles.ini`) lists profiles as `[ProfileN]` sections with `Name` and `Path`. The `[Install…]` section's `Default` is the profile the browser actually opens; others may be stale. On the test Mac, the `default` profile had never been used.

| State | Result |
| --- | --- |
| Quit | Zen starts in the profile and opens the link |
| Running, same profile | The link reaches the running Zen as a new tab, and the extra process exits |
| Running, other profile | A second Zen process starts for that profile, with its own Dock icon |
| Running both, link for the second profile | Goes to the second process; no third one starts |

Right after an update, Zen relaunched itself once (the new process carried `-foreground`) and showed a "what's new" sheet; the link still arrived. Zen didn't switch to the new tab while that sheet was open. Zen has no AppleScript, so tabs could only be checked through screenshots and window titles.

## Safari

Safari profiles (Safari 17 and later) have no command-line flag, URL scheme or scripting support. The only route is simulating the menu (File › New Window › New *Profile* Window), which needs Accessibility permission and breaks with any menu change. Safari stays a single row without profiles.
