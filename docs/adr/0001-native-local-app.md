# ADR 0001: One native, local macOS application

Status: accepted, 2026-10-17.

## Context

Blink needs fast URL intake, native focus and keyboard behavior, application discovery, and system default-handler integration. Its core operation does not require a server or web rendering engine.

## Decision

Use Swift with SwiftUI views and AppKit integration in one application. Keep routing logic independently testable. Store versioned local JSON configuration. Propose macOS 14+ and universal builds, subject to milestone-0 evidence.

Prefer direct Developer ID distribution with notarization. Determine sandbox feasibility experimentally before adopting a permanent entitlement policy. Do not introduce a helper process unless the integration proof establishes a concrete need.

## Alternatives and consequences

A web wrapper adds a runtime without removing the need for native integrations. A backend introduces availability and privacy costs without an MVP use case. An App Store release remains possible later but is not the initial distribution commitment.

Native implementation requires macOS build infrastructure and real-machine integration tests. Direct distribution requires signing, notarization, release hosting, and a manual update path initially.

## Verification

Accepted on the evidence in the [integration report](../integration-report.md): cold and warm delivery, discovery, explicit dispatch to five browsers, host normalization and focus all work as designed. Two revisions came out of it. The app is not sandboxed and ships with no entitlements. Pure logic sits in a local Swift package, `BlinkCore`, so it can be tested without launching the app; there is still one app target. Default-handler setup and login launch are implemented with Apple's public APIs but still need an end-to-end run in a separate account.
