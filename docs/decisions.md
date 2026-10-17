# Decisions and open questions

Updated: 2026-10-17. “Proposed” means a documented working assumption, not user approval. Implementation evidence and product decisions should change statuses explicitly.

## Confirmed

| Decision | Basis |
| --- | --- |
| Blink; “From link to browser, instantly.” | User selection in the shared conversation |
| Native macOS browser picker and intelligent link router | Product direction in that conversation |
| Minimal, premium, fast visual direction | Product identity described there |
| Arc, Dia, Chrome, Zen, Safari, and Brave compatibility | Explicit user requirement after the naming conversation |

## Proposed defaults

| Decision | Rationale | Record |
| --- | --- | --- |
| SwiftUI + AppKit, one local app | Native integration without a backend | [ADR 0001](adr/0001-native-local-app.md) |
| macOS 14+, Apple silicon and Intel | Initial compatibility baseline to validate | Milestone 0 |
| Direct signed/notarized distribution | Avoid committing to store constraints before integration proof | ADR 0001 |
| Manual picker plus ordered host rules | Useful first release with testable behavior | [ADR 0002](adr/0002-explicit-routing.md) |
| Profiles deferred | Browser-specific integration is unproven | Product scope |
| No URL history or telemetry | Link routing does not require either | Architecture |
| Manual updates for MVP | Avoid adding an update subsystem before the core works | Release plan |

## Questions and validation gates

| Question | Default / required evidence | Resolve by |
| --- | --- | --- |
| Is macOS 14 the right minimum? | Verify all APIs and test target machines; revise if justified | Milestone 0 |
| Can required integration run sandboxed? | Test discovery, URL intake, dispatch, defaults, and login; record entitlements | Milestone 0 |
| Does host normalization behave consistently? | Prove Unicode/punycode and IP fixtures with selected SDK | Milestone 0 |
| Which Xcode/Swift version? | Select installed stable toolchain that supports tested deployment target; pin in contribution guide/CI | Milestone 1 |
| What permanent bundle ID and signing team? | Owner supplies controlled reverse-DNS identity and signing account | Before distributable build |
| Are browser profiles essential for first release? | Current proposal defers them; if required, revise scope and prove per-browser support first | Before expanding MVP |
| Is Blink clear for public branding? | Name overlaps with Chromium terminology; branding review is pending, no legal conclusion is recorded | Before public launch |
| What license and commercial model? | Undecided; do not add a license, pricing, payment, or account flow by assumption | Before public distribution |
| Where are releases and support hosted? | Choose owner-controlled download location and support channel | Before public beta |
| What icon and localization scope? | Design original icon; initial UI copy in English is proposed, additional languages uncommitted | Before public beta |

## Decision process

Use an ADR for choices expensive to reverse, not every implementation detail. Include status, context, decision, consequences, and verification. Mark superseded decisions and link replacements. When a user changes scope, update the PRD, affected architecture, test plan, and milestone together.
