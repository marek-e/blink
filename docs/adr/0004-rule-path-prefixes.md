# ADR 0004: Rules can match a path prefix

Status: accepted, 2026-10-18.

## Context

A host rule is too coarse when one site serves several contexts by path. GitHub is the common case: `github.com/<company>` belongs in the work browser or profile while the rest of GitHub doesn't. Path rules were out of scope for the MVP ([product](../product.md)).

## Decision

A rule has an optional path prefix. Empty means any path, so existing rules behave as before. The prefix is compared one path segment at a time: `/team` matches `/team` and `/team/page` but not `/teams`. Matching ignores case, decodes percent-encoding before comparing, and ignores empty segments from repeated or trailing slashes. The prefix applies on top of the host match, including subdomains. Queries, fragments, wildcards and regular expressions stay unsupported.

The prefix is stored as `pathPrefix` in canonical form: a leading slash, single slashes between segments, no trailing slash, and every segment percent-encoded the same way. Rules without a prefix omit the key. An earlier rule shadows a later one only when it covers the later rule's hosts and its prefix is a segment prefix of the later rule's.

The configuration moves to schema version 3. Version 1 and 2 files load as version 3 and are rewritten on the next save.

## Alternatives and consequences

Keeping schema version 2 would let Blink 1.2 read the file, but 1.2 would ignore `pathPrefix`, so a rule for `github.com/team` would send all of GitHub there, and its next save would drop the prefix. As with ADR 0003, the bump makes older versions refuse the file and leave it untouched (product B12), at the cost of running without rules until the user upgrades again. The release notes must say so.

Plain string prefixes would be simpler but let `/team` match `/teams`. URL paths are case-sensitive by RFC 3986, and some servers treat `/Team` and `/team` as different pages. Matching them case-sensitively would follow the standard but miss links on sites that ignore case, such as GitHub owner and repository names. For a router, sending both to the same browser costs less than showing the picker for links that differ only in case.

## Verification

Tests cover segment matching, percent-encoding, case-insensitive matching, empty segments, subdomains with prefixes, precedence between path and host rules, shadowing, path normalization and rejection, the round trip of `pathPrefix`, and loading version 2 files.
