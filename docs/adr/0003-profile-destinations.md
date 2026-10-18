# ADR 0003: Destinations can name a browser profile

Status: accepted, 2026-10-18.

## Context

People keep work and personal browsing in separate profiles of one browser, and want some links to land in a specific one. Until now a destination was a bundle ID. The [capability matrix](../profiles-capability.md) shows that Arc, Dia, the Chrome family and the Firefox family can each be told which profile to use, through AppleScript or launch arguments. Safari can't.

## Decision

A destination is a bundle ID plus an optional profile reference. The reference holds a key that survives renames (an Arc space ID, a Chromium profile directory, a Firefox profile path) and the last name seen, for display when the profile is gone. Profile equality uses the key only.

Rules store a destination. The configuration moves to schema version 2: version 1 files are read and rewritten as version 2 on the next save, mapping `destinationBundleID` to a destination without a profile. Browser preferences gain a list of hidden profile keys.

A destination without a profile opens the browser exactly as before. With a profile, Blink checks at dispatch time that the profile still exists. If it doesn't, or macOS refuses Blink permission to control the browser, the request fails and the picker explains it. Blink never falls back to the browser's default profile on its own (ADR 0002).

## Alternatives and consequences

Keeping schema version 1 and adding an optional profile field would let Blink 1.1 read the file, but 1.1 would drop the profiles the first time it saved. A version bump makes 1.1 refuse the file and leave it untouched (product B12), at the cost of losing all rules in 1.1 until the user upgrades again. The release notes must say so.

Storing display names would be simpler, but renaming a space or profile would silently break rules. Dia and Firefox only accept names when opening a link, so Blink resolves the current name from the stored key at dispatch time.

Arc and Dia need Apple Events, so Blink gains the `com.apple.security.automation.apple-events` entitlement and an `NSAppleEventsUsageDescription`. macOS asks once per browser, the first time a link goes to one of its profiles.

## Verification

Tests cover decoding version 1 files, round-tripping version 2, profile equality by key, rule evaluation and request transitions with profiles, and each profile-list parser. Manual checks repeat the capability matrix with the release build.
