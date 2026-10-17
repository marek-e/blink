# Interaction design

Status: implemented. Covers [B01 to B17](product.md).

## Principles

Native controls, system typography, browser icons, restrained spacing and a visible selection. Light and dark appearance follow the system; colors are system colors, so Increase Contrast applies. Errors use an icon and text, never color alone. Animation is limited to the welcome window's page change and the Copy Link label, and both turn off with Reduce Motion. Nothing animates between a click and a dispatch.

Blink's icon is an original mark: a line from the left that forks toward three endpoints, with one branch highlighted. The menu bar icon is the same mark as a template image.

## First launch

The welcome window has five steps with a page indicator:

1. "Choose where your links open." with a short explanation.
2. Arrange your browsers: the same list as Settings › Browsers.
3. Make Blink your default browser. "Set Blink as Default Browser" asks macOS, which shows its own confirmation. Afterwards Blink reads both handlers back and shows one of three states: done, partial ("Blink opens HTTPS links, but HTTP links go to another app") or another browser by name. "Open System Settings" opens Desktop & Dock as a fallback. The footer button says "Not Now" until Blink is the default.
4. Open Blink at login: a toggle, off by default.
5. Done, with "Open Test Link" (queues `https://example.com/`) and "Done".

Links delivered or typed while the window is open wait. The footer counts them on every step, and steps 1 and 5 show "N links are waiting and will open when you finish." Closing the window counts as finishing, so links are never stuck behind it. Settings › General › Show Welcome… opens it again.

## Picker

A borderless rounded panel, 340 points wide, on the screen with the pointer. It's centered horizontally on the pointer with its top just above it, and it is moved so it never covers the menu bar or Dock or leaves the screen. It floats above other windows and stays open when Blink loses focus. It is a non-activating panel: it takes keyboard input and clicks even when macOS keeps another app active, for example a browser that just launched itself, so the first click on a row opens the link instead of only focusing the panel.

Top to bottom:

- The host in ASCII form (punycode for internationalized names), or the file name for a local file.
- A preview with scheme, host, port and path. A query or fragment shows as `?…` or `#…` so tokens aren't displayed by default.
- "Full link", a disclosure with the complete, selectable URL.
- A "N more links" badge when links are queued behind this one.
- A failure banner when needed (see below).
- Visible, available browsers in the user's order, with icon, name and shortcut number. The first is selected.
- "Always open example.com in the chosen browser", a checkbox, off by default. Shown only for web links that matched no rule while settings can be saved. Checking it and choosing a browser saves an exact-domain rule once the browser accepts the link. If that host already has an exact rule, Blink updates and enables it instead of adding another. A failed launch or a cancel saves nothing.
- Copy Link and Cancel.

| Input | Behavior |
| --- | --- |
| Up / Down | Move the selection, wrapping around |
| Return or Enter | Open in the selected browser |
| 1 to 9 | Open in that browser. Mapped by physical key, so it works on AZERTY and other layouts, and on the keypad |
| Click a browser | Open in that browser |
| Tab / Shift-Tab | Move between the checkbox and buttons (with Keyboard navigation turned on in System Settings) |
| Escape, ⌘W | Cancel this link; the next one appears |
| ⌘C, Copy Link | Copy the full original URL; the link stays pending |

Hovering highlights a row without moving the selection, because the panel opens under the pointer. Remembering the last choice is deliberately not offered; only the explicit checkbox creates a rule.

While more links are waiting, the browser receives each link in the background and Blink keeps focus, so the next picker takes keys right away. The last link brings its browser to the front.

While a link is being sent, the rows and Cancel are disabled and the chosen row says "Opening…". A browser that has to launch can take several seconds, and a newly downloaded browser waits for its Gatekeeper prompt, which appears above the picker. On success the panel closes or shows the next link.

VoiceOver announces "Open example.com. 5 browsers. 1 more link waiting." when the picker appears, the browser name as the selection moves, failures, and "Link copied". Each browser is a button with the hint "Press 1 to open". The window's title is "Choose a Browser".

## Settings

A toolbar-style window with three tabs. The window title follows the tab.

**General.** Default browser status and the same setup controls as the welcome window. Launch at login, with an "Open Login Items" button when macOS needs approval. Open Link…, Show Welcome…, version and build, Show settings file in Finder, and Reset Settings… (confirmation required, keeps a backup).

**Browsers.** One row per saved browser: icon, name, "Not installed" when missing, a "Show in picker" checkbox and up/down buttons. Rows can also be dragged. Uninstalled browsers have a Forget button. The last available visible browser can't be hidden, and its checkbox explains why. The header text says hidden browsers still work for rules. Refresh rescans.

**Rules.** An ordered list with an enable checkbox, domain, "This domain only" or "This domain and its subdomains", and the destination's icon and name. Warnings appear inline: "Never used: the rule for example.com above matches first." and "Brave Browser isn't installed. Matching links will ask you to choose." Add, Delete, Edit…, Move Up and Move Down sit below the list. Double-click edits, Delete removes, and rows can be dragged or used from the context menu. "Test a link" shows what Blink would do with any URL.

The rule editor is a sheet with Domain, Include subdomains, Open in, and Enabled. It accepts a host only and shows the normalized result as you type ("Matches docs.example.com exactly") or the specific error ("Enter only the domain, without a port."). Include subdomains is disabled for IP addresses and single-label hosts. Open in lists installed browsers, including hidden ones. When editing a rule whose browser is gone, that browser stays selectable as "(not installed)" so the rule can be saved unchanged; new rules need an installed browser. The editor warns when an earlier rule would shadow this one, or when this one would shadow later rules.

## Open Link

From the menu bar, Settings, or ⌘L while Blink is active. A text field takes a complete HTTP or HTTPS link; errors appear under it ("Enter a complete link that starts with http:// or https://."). Open sends the link through the normal pipeline, so rules apply. This is how to try Blink before making it the default.

## Recovery states

| State | Behavior |
| --- | --- |
| No eligible browsers | "No browser is available for this link" with Refresh and Settings; Copy Link and Cancel stay available |
| Rule's browser missing | Banner names the browser and says a rule sent the link there. Other visible browsers and "Edit Rules" are offered. Later rules are not tried |
| Chosen browser missing | Banner names it and asks for another browser |
| Browser refused the link | Banner with Try Again; other browsers, Copy Link and Cancel remain |
| Browser hasn't answered after 10 s | The picker appears (even for a rule-routed link) with "Still waiting for <browser>" and the browser's row highlighted. Cancel and Escape work; other browsers stay disabled until macOS answers, so the link can't open twice |
| Invalid link from another app | An alert: "Blink can't open this link" with the specific reason. Several arrive as separate alerts, one after another |
| Settings can't load | Settings opens on the General tab at launch. It explains whether the file is damaged or from a newer Blink, says the file is untouched and temporary defaults are in use, and offers Reset Settings… and Show in Finder. Editing controls are disabled |
| Settings can't save | Alert: "Blink couldn't save your settings. Your previous settings are still in effect." with Try Again. Inside the rule editor the message appears inline |
| Quit with links waiting | "Discard 2 links that haven't opened yet?" with Keep Blink Open (default) and Discard and Quit |

Links are never written to disk, so a crash loses waiting links. Blink doesn't claim otherwise.
