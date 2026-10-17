# Blink

From link to browser, instantly.

Blink is a lightweight, native macOS browser picker and intelligent link router. Choose a browser when opening a link, or let your own rules choose it for you.

**Status:** product planning. This repository contains specifications, not a working application. There are no build or test commands yet.

## Start here

1. [Product requirements](docs/product.md): audience, proposed MVP, and acceptance criteria.
2. [Interaction design](docs/interaction-design.md): onboarding, picker, settings, and error states.
3. [Architecture](docs/architecture.md): macOS integration, data contracts, routing, and persistence.
4. [Build plan](docs/build-plan.md): ordered milestones and completion checks.
5. [Testing and release](docs/testing-and-release.md): validation matrix and shipping checklist.

[Project context](CONTEXT.md) summarizes confirmed decisions and assumptions. [Decisions and open questions](docs/decisions.md) tracks what still needs validation. [Contributor guidance](CONTRIBUTING.md) explains how to work in this repo.

## Proposed first release

- A keyboard-accessible browser picker for HTTP and HTTPS links delivered to Blink.
- Browser discovery, ordering, and visibility settings.
- Explicit, ordered domain rules for automatic routing.
- Optional default-browser and launch-at-login setup.
- Local storage, no account, no browsing history collection.

Browser profiles, private windows, source-app rules, and cloud sync are outside the initial MVP. These boundaries are proposals, not decisions recorded in the naming conversation.

## Source and ownership

The [shared naming conversation](https://chatgpt.com/share/6ad3dadb-a130-83eb-a8e4-5e669b0ee31c) establishes Blink's name, tagline, native macOS purpose, and visual direction. It does not contain a detailed PRD. The documents here supply an explicit proposed implementation baseline.

No software license has been selected. Do not infer redistribution rights or a commercial model from this repository.
