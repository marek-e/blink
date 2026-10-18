# Project context

Updated: 2026-10-17, after the first implementation.

## Confirmed direction

- Product name: Blink.
- Tagline: From link to browser, instantly.
- Purpose: a lightweight native macOS browser picker and intelligent link router.
- Visual direction: minimal, premium, fast, with a distinctive icon.
- Required browser compatibility: Arc, Dia, Chrome, Zen, Safari, and Brave, specified by the user after the naming conversation.
- Source: [shared naming conversation](https://chatgpt.com/share/6ad3dadb-a130-83eb-a8e4-5e669b0ee31c).

The shared excerpt begins during naming exploration. No earlier feature requirements, architecture, or commercial decisions were available.

## Implementation

Blink is built: one Swift macOS app using SwiftUI and AppKit, with routing logic in the local `BlinkCore` package. It targets macOS 14 and builds as a universal binary. Direct distribution as a Developer ID-signed, notarized app is scripted but has not run, because no signing identity is available yet. The [integration report](docs/integration-report.md) records what was verified and on what.

"Intelligent" means deterministic user-defined rules. There is no AI model, remote service or inference from browsing activity.

URLs stay in memory. Browser preferences and rules are stored locally. Blink doesn't fetch URLs, strip query parameters or follow redirects. It reads browsers' profile lists for profile IDs and names only.

## Domain language

| Term | Meaning |
| --- | --- |
| Open request | One URL delivered to Blink, with an internal request ID |
| Browser | An installed application eligible to handle web URLs |
| Destination | A browser identified by bundle ID, and optionally one of its profiles |
| Profile | A browser profile, or an Arc space, identified by a key that survives renames (space ID, profile directory or path) |
| Rule | A domain match and destination, evaluated in list order when enabled |
| Shadowed rule | A rule that an earlier enabled rule always matches first, so it never applies |
| Picker | The temporary window used to choose a destination |
| Default browser | The macOS handler for a URL scheme, distinct from a Blink preference |
| Available | Installed and currently eligible to handle the request's scheme |
| Visible | Included in the manual picker by user preference |

## Reading order and authority

Read this file, [product requirements](docs/product.md), and [architecture](docs/architecture.md) before changing behavior. Requirement IDs in the product document identify expected behavior. The [decision register](docs/decisions.md) lists what is settled and what is still open.

Update related documents together when scope changes. Preserve the distinction between confirmed product direction, proposed behavior, and experimentally verified platform support.
