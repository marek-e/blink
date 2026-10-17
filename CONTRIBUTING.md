# Contributing

This repository is documentation-only. Do not run or advertise nonexistent build commands. The first implementation milestone must add an Xcode project, a shared scheme, and exact local and CI build/test instructions here.

## Before changing code

1. Read [project context](CONTEXT.md), the relevant requirements, and [open decisions](docs/decisions.md).
2. State assumptions and define a check that will establish success.
3. Keep changes scoped to the requested behavior. Avoid speculative abstractions and unrelated cleanup.
4. For a bug, reproduce it before fixing it. For logic changes, cover meaningful boundary cases.

Use `codex/` as the default prefix for new work branches. Do not commit signing credentials, provisioning assets containing secrets, personal URLs, browser profile files, or local settings.

## Implementation conventions

- Prefer platform frameworks and a single app target; add dependencies only for a demonstrated need.
- Keep routing logic independent of AppKit and filesystem access.
- Keep UI state on the main actor. Serialize configuration writes and request state transitions.
- Pass destinations explicitly when opening links. Never hand a routed link back to the system default handler.
- Never construct a shell command from a URL.
- Use synthetic domains such as `example.com` in fixtures and screenshots.

## Definition of done

A change satisfies its requirement IDs, handles its documented errors, and has appropriate verification. UI work includes keyboard and VoiceOver checks. Update affected specifications and record any intentional departure from a proposed decision. Describe checks actually run and remaining limitations in the PR.

Documentation changes need local link and consistency checks. Runtime tests are required when implementation exists, not as a substitute for reading the documentation.
