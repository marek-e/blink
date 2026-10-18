# ADR 0002: Explicit first-match routing

Status: accepted, 2026-10-17.

## Context

Links may belong to different browser sessions. Routing to an unexpected browser can be worse than asking the user. “Intelligent routing” needs predictable semantics before adding more conditions.

## Decision

Evaluate enabled host rules in user-visible order, stopping at the first match. Exact host matching is the default, with subdomains explicitly included. No match opens the picker. An unavailable matched destination opens recovery choices instead of falling through to later rules or the system default.

Use explicit application dispatch. Keep the URL unchanged and do not infer new rules from past choices. No request history is needed. Browser visibility affects the picker only, not rule eligibility.

## Alternatives and consequences

Most-specific-rule ordering is harder to reconcile with a user-arranged list. Silent fallback may open a sensitive link in the wrong session. Automatic learning needs history and introduces choices the user did not specify.

First-match ordering means a broad rule can shadow a later narrow rule. The rule editor must explain precedence and warn on duplicate rules. Tests must include overlaps, unavailable destinations, domain boundaries, and disabled rules.

## Verification

Accepted. Table-driven tests cover normalization, matching, overlaps, disabled rules and unavailable first matches. Manual checks confirmed that a rule to a missing browser opens the recovery picker without trying later rules, and that rules dispatch to Arc, Dia, Chrome, Zen and Safari. One extension: the picker can create an exact rule when the user ticks a checkbox (product B15). It still never learns from choices on its own.
