# Interaction design

Status: proposed. Implements [B01–B13](product.md).

## Visual and interaction principles

Use native macOS controls, system typography, browser application icons, restrained spacing, and a clear focus indicator. Support light and dark appearances. Use text as well as color for errors and selection. Blink's own icon remains an open design task; do not substitute another product's mark.

Animate only when it helps orientation, and respect Reduce Motion. No animation should delay opening a link. Do not put developer identifiers or routing implementation details in ordinary user flows.

## First launch

Show a short explanation: “Choose where your links open.” Display discovered browsers and let the user arrange them. Offer “Set Blink as default” and “Not now.” Explain that this affects links sent through the system default browser.

After the system interaction, query each scheme's actual handler. If only one scheme is assigned, show a partial-setup state rather than claiming completion. Provide a System Settings fallback if the API is unavailable or fails. Verify the relevant settings path during milestone 0 instead of hard-coding an untested deep link.

Offer launch at login separately, off by default. Finish with a test link the user explicitly opens. If first launch was caused by a URL, retain it while onboarding and then handle it normally; skipping default-browser setup must not discard it.

## Picker

Use a compact window with a vertical browser list, names, and icons. Show the request's hostname prominently and a selectable, truncated URL preview. A disclosure exposes the complete URL without fetching it. Avoid exposing query tokens in the default preview. Display internationalized hosts in ASCII/punycode form to reduce ambiguous visual matching.

Position on the screen containing the pointer without covering the menu bar or leaving the visible screen area. Validate placement with multiple displays. Focus the first visible browser. Do not remember the last choice as an implicit routing rule.

| Input | Behavior |
| --- | --- |
| Up / Down | Move browser selection |
| Return | Open in selected browser |
| Tab / Shift-Tab | Traverse controls in logical order |
| Escape or window close | Cancel current request |
| Click browser | Open in that browser |
| Copy Link | Copy the full original URL; leave request pending |

Announce the hostname, browser names, selection, errors, and queue count to VoiceOver. Give icon-only buttons accessible labels. Long browser names and URLs must not push controls offscreen.

Disable dispatch controls while opening to prevent double submission. On success, close the current request and process the next. Losing focus leaves the picker pending. When requests arrive while a picker is open, append them and show “N more links” without replacing the active URL.

## Settings

- **General:** default-handler status, explicit setup action, login status/toggle, and app version.
- **Browsers:** discovered apps, visibility toggles, reorder controls usable without dragging, refresh, and unavailable saved destinations.
- **Rules:** ordered list showing domain, subdomain setting, destination, and enabled state. Explain “The first matching rule wins.”

The rule editor accepts a host only, not a complete URL. Reject schemes, ports, paths, empty labels, wildcards, credentials, and whitespace. Show the normalized host before saving. Exact matching is selected initially. An explicit checkbox includes the domain itself and its subdomains. Duplicate rules are allowed but warn that earlier matching rules take precedence.

Creating a rule requires an available browser destination. Hiding a browser only removes it from manual choices; a rule pointing to it continues to work. State this beside the visibility setting.

The menu's Open Link action accepts a pasted absolute HTTP/HTTPS URL and enters the normal request pipeline. It is a way to test Blink before changing the system default.

## Recovery states

| State | User-facing behavior |
| --- | --- |
| No eligible browsers | Explain that no browser is available for this link; offer Refresh, Copy Link, and Cancel. |
| Matched destination missing | Name the unavailable browser; show other visible choices and a Settings action. Do not evaluate later rules automatically. |
| Browser launch failed | Keep the URL pending; offer Retry, another browser, Copy Link, and Cancel. |
| Unsupported/invalid URL | Explain that Blink opens valid HTTP and HTTPS links; do not dispatch. |
| Configuration cannot load | Explain that saved settings could not load; keep the original file; use temporary defaults without saving over it. Offer explicit reset. |
| Settings cannot save | Keep the last durable configuration authoritative, roll back the displayed edit, and offer retry. |
| Quit with pending requests | Ask whether to discard pending links or continue. Pending links are never saved to disk. |

Reset requires confirmation, backs up the original settings, and writes a new default configuration. On a process crash, memory-only pending requests are lost; do not claim crash recovery of links.
