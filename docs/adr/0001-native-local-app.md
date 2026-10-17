# ADR 0001: One native, local macOS application

Status: proposed. Date: 2026-10-17.

## Context

Blink needs fast URL intake, native focus and keyboard behavior, application discovery, and system default-handler integration. Its core operation does not require a server or web rendering engine.

## Decision

Use Swift with SwiftUI views and AppKit integration in one application. Keep routing logic independently testable. Store versioned local JSON configuration. Propose macOS 14+ and universal builds, subject to milestone-0 evidence.

Prefer direct Developer ID distribution with notarization. Determine sandbox feasibility experimentally before adopting a permanent entitlement policy. Do not introduce a helper process unless the integration proof establishes a concrete need.

## Alternatives and consequences

A web wrapper adds a runtime without removing the need for native integrations. A backend introduces availability and privacy costs without an MVP use case. An App Store release remains possible later but is not the initial distribution commitment.

Native implementation requires macOS build infrastructure and real-machine integration tests. Direct distribution requires signing, notarization, release hosting, and a manual update path initially.

## Verification

Milestone 0 must prove cold/warm URL delivery, browser discovery/dispatch, default-handler setup, login launch, normalization, and focus behavior. Record sandbox results and SDK/API availability. Accept or revise this ADR after that evidence exists.
