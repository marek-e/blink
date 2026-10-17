# macOS integration report

Recorded 2026-10-17 and 2026-10-18. Most results come from the development Mac. A macOS 14.8.7 virtual machine (Tart, `cirruslabs/macos-sonoma-vanilla`) covered the minimum OS and the quit state of Arc, Dia and Safari, and Rosetta covered the x86_64 slice. See [testing and release](testing-and-release.md) for the full matrix.

## Environment

| Item | Value |
| --- | --- |
| Machine | Apple silicon (arm64) |
| macOS | 26.6.2 (25G83) |
| Xcode | 27.1 (27A9275), Swift 6.4, macOS 27.0 SDK |
| Deployment target | macOS 14.0; the compiler enforces availability, and the app builds without availability errors |
| Build | Universal binary (`x86_64 arm64`), ad-hoc signed |
| Browsers | Arc 1.168.0, Dia 1.53.0, Google Chrome 155.0.8059.84, Zen 1.17.14b, Safari 26.6.2, Brave 1.97.59 (installed for the test, then removed) |

## Findings

**Host normalization.** `URLComponents.encodedHost` converts Unicode hosts to punycode (`Bücher.Example.` becomes `xn--bcher-kva.example.`) but keeps letter case, trailing dots, percent escapes and empty labels. Blink lowercases, strips one trailing dot, and rejects percent-encoded hosts and empty labels. The same function normalizes rule input by parsing `https://` plus the entered host. Tests in `HostAndLinkTests.swift` pin this behavior.

**Discovery.** `NSWorkspace.urlsForApplications(toOpen:)` for `http` and `https` returns every registered handler. On the test machine that included ChatGPT and cmux, which are not browsers, and two copies of Google Chrome for Testing. Blink dedupes by bundle ID and resolves the copy macOS prefers with `urlForApplication(withBundleIdentifier:)`. Apps that also handle `public.html` are treated as browsers and start visible. The others start hidden but stay listed. On this machine that rule exactly separated browsers from non-browsers.

**Intake.** `application(_:open:)` receives links on cold launch before `applicationDidFinishLaunching`, so the model is created in `applicationWillFinishLaunching`. No Apple Event handler is registered, so there's no duplicate intake. Local HTML files arrive through the same method.

**Dispatch.** `NSWorkspace.open(_:withApplicationAt:configuration:)` was accepted for every tested browser, running or not. Cold launches of Chrome and Zen took 4.8 s and 4.1 s before macOS accepted the link. Running browsers accepted links in about 20 ms.

**Activation.** macOS 14 activation is cooperative. Without `NSApp.yieldActivation(toApplicationWithBundleIdentifier:)`, the browser received the link but Blink stayed frontmost. Rule-routed links hit a second problem: macOS activates Blink to deliver the link, sometimes after Blink has already sent it on. Blink now yields before dispatching, activates the browser from the completion handler, and hands activation back if it becomes active with no window within two seconds of a dispatch. After the fix, all six browsers came to the front for manual and rule dispatch.

**Slow and stuck dispatches.** macOS reports a dispatch only when the browser acknowledges it. A newly downloaded Brave waited 30.5 s on its Gatekeeper prompt. In the VM, cold browsers took about 30 s, and a quarantined Dia, run from App Translocation, never answered. A rule-routed link would then wait invisibly and block the queue. After 10 s without an answer, Blink now shows the picker with "Still waiting for <browser>" and lets the user cancel. A late answer for a cancelled request is ignored.

**Picker focus.** When macOS keeps another app active (a browser that launched itself, or a link delivered with `open -g`), an ordinary panel shows but can't take keys, and the first click only focuses it. The picker is a non-activating panel, so keys and the first click work in both cases.

**Window sizing.** A titled `.fullSizeContentView` window hosting SwiftUI with `sizingOptions = .preferredContentSize` crashed with "too many Update Constraints passes" on macOS 26. The picker is therefore a borderless panel that draws its own rounded material, and the welcome window is a normal titled window.

**Keyboard.** Key codes are physical positions. The test machine uses AZERTY, where the top-row key printed "7" types "è" without Shift. The picker maps key codes 18 to 28 and the numeric keypad to 1 to 9, so number shortcuts work on any layout.

**macOS 14.** The universal build (minimum OS 14.0) ran on macOS 14.8.7. Discovery found Arc, Dia and Safari. Rules dispatched to each from a quit state, and the picker, Settings and welcome window rendered correctly. On macOS 14, unpacking an app into `/Applications` over SSH was refused, so the VM used `~/Applications`.

**Intel.** The x86_64 slice ran translated under Rosetta. The test suite passed, and the picker and both kinds of dispatch worked.

**Sandbox.** Not adopted. Blink is distributed directly with the hardened runtime and no entitlements. Discovery, dispatch, default-handler changes and `SMAppService` need no extra entitlement outside the sandbox. A sandboxed build was not attempted; an App Store release would need that study.

**Login item.** `SMAppService.mainApp.register()` and `unregister()` work for an ad-hoc signed build, and `status` reports `enabled` and then `notRegistered`. The "requires approval" state can't be reached: macOS uses it for background items, and Blink registers as an "Open at Login" app.

**Default browser.** The code uses `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` for HTTP, then HTTPS if it isn't already Blink. macOS asks once and changes HTTP and HTTPS together. Declining leaves both handlers unchanged, and Blink notices changes made outside it. A partial assignment can't be produced on macOS 26 (changing HTTPS alone fails with error 256), so that state is covered by unit tests. The development Mac's default was restored to Arc after the test.

## Measurements

The full performance run (100 warm and 20 cold samples, 60 s idle) is in [testing and release](testing-and-release.md#performance). All four targets are met.
