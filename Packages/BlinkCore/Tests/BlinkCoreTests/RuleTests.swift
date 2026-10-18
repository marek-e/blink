import Foundation
import Testing
@testable import BlinkCore

@Suite("Rule evaluation")
struct RuleTests {
    private func rule(_ domain: String, subdomains: Bool = false, path: String = "", to browser: String = "b", enabled: Bool = true) -> Rule {
        Rule(domain: domain, includeSubdomains: subdomains, pathPrefix: path, destination: .init(bundleID: browser), isEnabled: enabled)
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
        #expect(RuleEvaluator.evaluate(host: "docs.example.com", path: "/", rules: rules)
            == .matched(ruleID: broad.id, destination: .init(bundleID: "broad")))
        #expect(RuleEvaluator.evaluate(host: "docs.example.com", path: "/", rules: [disabled, narrow, broad])
            == .matched(ruleID: narrow.id, destination: .init(bundleID: "narrow")))
        #expect(RuleEvaluator.evaluate(host: "other.test", path: "/", rules: rules) == .noMatch)
        #expect(RuleEvaluator.evaluate(host: "", path: "/", rules: rules) == .noMatch)
        #expect(RuleEvaluator.evaluate(host: "example.com", path: "/", rules: []) == .noMatch)
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

    @Test(arguments: [
        ("/hublo", "/hublo", true),
        ("/hublo", "/hublo/", true),
        ("/hublo", "/hublo/repo/pulls", true),
        ("/hublo", "//hublo//repo", true),
        ("/hublo", "/hublo-other", false),
        ("/hublo", "/hublos/repo", false),
        ("/hublo", "/Hublo/repo", true),
        ("/Hublo", "/hublo", true),
        ("/caf%C3%A9", "/CAF%C3%89", true),
        ("/a%2Ab", "/a*b", true),
        ("/hublo", "/", false),
        ("/hublo", "", false),
        ("/hublo", "/other/hublo", false),
        ("/caf%C3%A9", "/caf%C3%A9/menu", true),
        ("/caf%C3%A9", "/caf%c3%a9", true),
        ("/caf%C3%A9", "/caf\u{E9}", true),
        ("/a%2Fb", "/a/b", false),
        ("/a%20b", "/a%20b/c", true),
        ("", "/anything", true),
        ("", "", true),
    ])
    func pathMatching(prefix: String, path: String, matches: Bool) {
        let decision = RuleEvaluator.evaluate(host: "github.com", path: path, rules: [rule("github.com", path: prefix)])
        #expect((decision != .noMatch) == matches)
    }

    @Test func pathRulesStillMatchTheHost() {
        let scoped = rule("github.com", subdomains: true, path: "/hublo")
        #expect(RuleEvaluator.evaluate(host: "gist.github.com", path: "/hublo/x", rules: [scoped]) != .noMatch)
        #expect(RuleEvaluator.evaluate(host: "gitlab.com", path: "/hublo/x", rules: [scoped]) == .noMatch)
    }

    @Test func pathRulesBeforeHostRulesWin() {
        let team = rule("github.com", path: "/hublo", to: "arc")
        let everything = rule("github.com", to: "safari")
        let rules = [team, everything]
        #expect(RuleEvaluator.evaluate(host: "github.com", path: "/hublo/app", rules: rules)
            == .matched(ruleID: team.id, destination: .init(bundleID: "arc")))
        #expect(RuleEvaluator.evaluate(host: "github.com", path: "/apple/swift", rules: rules)
            == .matched(ruleID: everything.id, destination: .init(bundleID: "safari")))
    }

    @Test func detectsShadowedPathRules() {
        let host = rule("github.com")
        let team = rule("github.com", path: "/hublo")
        let repo = rule("github.com", path: "/hublo/app")
        let other = rule("github.com", path: "/hublos")
        #expect(RuleEvaluator.shadowingRule(for: team, in: [host, team]) == host)
        #expect(RuleEvaluator.shadowingRule(for: host, in: [team, host]) == nil)
        #expect(RuleEvaluator.shadowingRule(for: repo, in: [team, repo]) == team)
        #expect(RuleEvaluator.shadowingRule(for: team, in: [repo, team]) == nil)
        #expect(RuleEvaluator.shadowingRule(for: other, in: [team, other]) == nil)
        let upperRepo = rule("github.com", path: "/Hublo/App")
        #expect(RuleEvaluator.shadowingRule(for: upperRepo, in: [team, upperRepo]) == team)

        let teamEverywhere = rule("github.com", subdomains: true, path: "/hublo")
        #expect(RuleEvaluator.shadowingRule(for: teamEverywhere, in: [team, teamEverywhere]) == nil)
        #expect(RuleEvaluator.shadowingRule(for: team, in: [teamEverywhere, team]) == teamEverywhere)
    }

    @Test(arguments: [
        ("", ""),
        ("/", ""),
        ("  /hublo  ", "/hublo"),
        ("hublo", "/hublo"),
        ("/hublo/", "/hublo"),
        ("//hublo//app/", "/hublo/app"),
        ("/caf%C3%A9", "/caf%C3%A9"),
        ("/caf%c3%a9", "/caf%C3%A9"),
        ("/caf\u{E9}", "/caf%C3%A9"),
        ("/a%20b", "/a%20b"),
        ("/100%25", "/100%25"),
        ("/a@b:c;d=e", "/a@b:c;d=e"),
        ("/a%2Ab", "/a%2Ab"),
        ("/Hublo", "/Hublo"),
    ])
    func normalizesPaths(input: String, expected: String) {
        #expect(RulePath.normalize(input) == .success(expected))
    }

    @Test(arguments: [
        ("https://github.com/hublo", RulePathError.includesScheme),
        ("/hublo?tab=repos", .includesQuery),
        ("/hublo#readme", .includesQuery),
        ("/hublo/*", .includesWildcard),
        ("/hub lo", .includesWhitespace),
        ("/a%2Fb", .invalidCharacters),
        ("/100%", .invalidCharacters),
        ("/a%00b", .invalidCharacters),
        ("/a\\b", .invalidCharacters),
    ])
    func rejectsPaths(input: String, expected: RulePathError) {
        #expect(RulePath.normalize(input) == .failure(expected))
    }
}
