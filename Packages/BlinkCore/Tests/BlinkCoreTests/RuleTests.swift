import Foundation
import Testing
@testable import BlinkCore

@Suite("Rule evaluation")
struct RuleTests {
    private func rule(_ domain: String, subdomains: Bool = false, to browser: String = "b", enabled: Bool = true) -> Rule {
        Rule(domain: domain, includeSubdomains: subdomains, destination: .init(bundleID: browser), isEnabled: enabled)
    }

    @Test(arguments: [
        ("example.com", false, "example.com", true),
        ("example.com", false, "docs.example.com", false),
        ("example.com", true, "example.com", true),
        ("example.com", true, "docs.example.com", true),
        ("example.com", true, "a.b.example.com", true),
        ("example.com", true, "notexample.com", false),
        ("example.com", true, "example.com.evil.test", false),
        ("example.com", true, "example.co", false),
        ("localhost", true, "a.localhost", false),
        ("10.0.0.1", true, "10.0.0.1", true),
        ("0.0.1", true, "10.0.0.1", false),
        ("[::1]", true, "[::1]", true),
    ])
    func matching(domain: String, subdomains: Bool, host: String, matches: Bool) {
        #expect(rule(domain, subdomains: subdomains).matches(host: host) == matches)
    }

    @Test func firstEnabledMatchWins() {
        let disabled = rule("example.com", to: "disabled", enabled: false)
        let broad = rule("example.com", subdomains: true, to: "broad")
        let narrow = rule("docs.example.com", to: "narrow")
        let rules = [disabled, broad, narrow]
        #expect(RuleEvaluator.evaluate(host: "docs.example.com", rules: rules)
            == .matched(ruleID: broad.id, destination: .init(bundleID: "broad")))
        #expect(RuleEvaluator.evaluate(host: "docs.example.com", rules: [disabled, narrow, broad])
            == .matched(ruleID: narrow.id, destination: .init(bundleID: "narrow")))
        #expect(RuleEvaluator.evaluate(host: "other.test", rules: rules) == .noMatch)
        #expect(RuleEvaluator.evaluate(host: "", rules: rules) == .noMatch)
        #expect(RuleEvaluator.evaluate(host: "example.com", rules: []) == .noMatch)
    }

    @Test func detectsShadowedRules() {
        let broad = rule("example.com", subdomains: true)
        let exactDuplicate = rule("example.com")
        let narrow = rule("docs.example.com", subdomains: true)
        let unrelated = rule("example.org")
        let rules = [broad, exactDuplicate, narrow, unrelated]
        #expect(RuleEvaluator.shadowingRule(for: broad, in: rules) == nil)
        #expect(RuleEvaluator.shadowingRule(for: exactDuplicate, in: rules) == broad)
        #expect(RuleEvaluator.shadowingRule(for: narrow, in: rules) == broad)
        #expect(RuleEvaluator.shadowingRule(for: unrelated, in: rules) == nil)

        let exact = rule("example.com")
        let wider = rule("example.com", subdomains: true)
        #expect(RuleEvaluator.shadowingRule(for: wider, in: [exact, wider]) == nil)
        let disabledEarlier = rule("example.com", enabled: false)
        #expect(RuleEvaluator.shadowingRule(for: exact, in: [disabledEarlier, exact]) == nil)
    }
}
