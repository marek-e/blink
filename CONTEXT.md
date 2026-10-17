# Project context

Updated: 2026-10-17.

## Confirmed direction

- Product name: Blink.
- Tagline: From link to browser, instantly.
- Purpose: a lightweight native macOS browser picker and intelligent link router.
- Visual direction: minimal, premium, fast, with a distinctive icon.
- Required browser compatibility: Arc, Dia, Chrome, Zen, Safari, and Brave, specified by the user after the naming conversation.
- Source: [shared naming conversation](https://chatgpt.com/share/6ad3dadb-a130-83eb-a8e4-5e669b0ee31c).

The shared excerpt begins during naming exploration. No earlier feature requirements, architecture, or commercial decisions were available.

## Proposed implementation baseline

Use Swift, SwiftUI, and AppKit in one macOS app. Start with macOS 14 or later, Apple silicon and Intel, subject to the compatibility checks in milestone 0. Distribute directly as a signed and notarized app. These are engineering proposals, not user-approved platform commitments.

The MVP offers manual browser selection and ordered domain routing. “Intelligent” means deterministic user-defined rules; it does not imply an AI model, remote service, or automatic inference from browsing activity.

Keep URLs in memory only. Store browser preferences and rules locally. Do not fetch URLs, strip query parameters, follow redirects, or inspect browser profiles in the MVP.

## Domain language

| Term | Meaning |
| --- | --- |
| Open request | One URL delivered to Blink, with an internal request ID |
| Browser | An installed application eligible to handle web URLs |
| Destination | A browser identified by bundle ID; profiles are a future extension |
| Rule | An enabled domain match and destination, evaluated in list order |
| Picker | The temporary window used to choose a destination |
| Default browser | The macOS handler for a URL scheme, distinct from a Blink preference |
| Available | Installed and currently eligible to handle the request's scheme |
| Visible | Included in the manual picker by user preference |

## Reading order and authority

Read this file, [product requirements](docs/product.md), and [architecture](docs/architecture.md) before implementing. Requirement IDs in the product document identify expected behavior. The [decision register](docs/decisions.md) identifies uncertainty; proposed ADRs are not accepted decisions.

Update related documents together when scope changes. Preserve the distinction between confirmed product direction, proposed behavior, and experimentally verified platform support.
