# Build plan

Status: milestones 0 to 4 are done; milestone 5 is blocked on a signing identity and on tests that need other machines or accounts. Requirements are defined in [product.md](product.md).

| Milestone | State |
| --- | --- |
| 0. Prove macOS integration | Done on macOS 26 / Apple silicon. See the [integration report](integration-report.md). macOS 14, Intel and Brave remain untested. |
| 1. Application foundation | Done. XcodeGen project, shared `Blink` scheme, menu bar app, settings, versioned store, CI workflow. |
| 2. Manual picker | Done. |
| 3. Deterministic routing | Done. ADR 0002 accepted. |
| 4. Onboarding and reliability | Done, except an end-to-end run of the default-browser change in a separate account. |
| 5. Distributable beta | `scripts/release.sh` is ready. Needs a Developer ID, notarization credentials, a permanent bundle ID, a license decision and the remaining matrix checks. |

## 0. Prove macOS integration

Create a minimal disposable app target to test URL registration and cold/warm intake, discovery, explicit dispatch to Arc, Dia, Chrome, Zen, Safari, and Brave, and default-handler changes. Check both HTTP and HTTPS independently. Prove that launch at login can be enabled, disabled, and observed accurately. Test URL host normalization, especially Unicode and trailing dots.

Compare required operations with App Sandbox enabled and disabled. Record actual entitlements, supported OS versions, Xcode version, architecture, and browser versions. Confirm keyboard focus and window activation from background URL delivery. Resolve the platform questions in [decisions.md](decisions.md) before building around assumptions.

**Exit:** a reproducible integration report, a validated minimum OS, and accepted or revised ADR 0001. No production feature should rely on an unverified browser CLI flag or private API.

## 1. Create the application foundation

Create the permanent Xcode app project, shared `Blink` scheme, app identity, and unit-test target. Add the menu bar item, Settings window, and versioned configuration store. Add build instructions to CONTRIBUTING with the actual project path and supported toolchain. Add CI on a macOS runner for compilation and unit tests; signing is not needed for every test build.

**Verify:** clean checkout builds, menu bar app launches, configuration round-trips, and corrupt/newer-version files remain intact. Covers B08 and B12.

## 2. Deliver the manual picker

Implement URL validation, browser discovery, memory queue, picker, explicit dispatch, and failure recovery. Add Open Link for testing before setting Blink as default. Add browser ordering and visibility. Implement the documented keyboard behavior and accessibility labels from the beginning.

**Verify:** no-match links open in the selected browser on cold and warm launches; multiple requests retain order; cancellation and double activation behave correctly; missing browsers and dispatch failures retain the active request. Covers B01-B04, B06, B10, B11, and B13.

## 3. Add deterministic routing

Implement the pure rule evaluator and rule editor. Use one normalization implementation for input and rules. Add enable/disable, ordering, duplicate-rule warnings, and destination availability feedback. Preserve URL content during dispatch.

**Verify:** table-driven matching tests and rule persistence pass; first-match wins, including when that destination is unavailable; hidden browsers remain usable by rules. Covers B05 and routing portions of B06/B13. Accept or revise ADR 0002.

## 4. Complete onboarding and reliability

Add explicit default-browser setup with verified status, opt-in login launch, onboarding with pending requests, configuration recovery/reset, and quit confirmation for queued links. Complete dark mode, contrast, reduced motion, VoiceOver, and multi-display behavior. Audit logs and filesystem writes for privacy.

**Verify:** declined/partial default setup works, login status tracks OS changes, failed writes roll back UI, and queued links are neither persisted nor exposed in logs. Covers B07-B10 and B12.

## 5. Prepare a distributable beta

Run the complete [test and release checklist](testing-and-release.md). Record performance on named reference hardware. Produce a signed, notarized build and test a downloaded copy on a clean user account. Document installation, default-browser reversal, quitting, and uninstalling. Resolve ownership/license and release identity before public distribution.

**Exit:** all B01-B13 criteria have recorded evidence, remaining limitations are stated, and release gates pass. Do not claim support for browser profiles or untested browsers.

## After the MVP

Evaluate browser profiles first, using a separate capability matrix and a proof for each browser and running/not-running state. Then consider private windows, source-app rules, optional URL cleanup, and a signed updater based on user demand. Each addition needs its own scope, privacy review, and acceptance criteria; this list does not authorize implementation.
