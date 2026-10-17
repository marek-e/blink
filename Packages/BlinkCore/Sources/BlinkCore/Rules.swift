import Foundation

public struct Rule: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var domain: String
    public var includeSubdomains: Bool
    public var destinationBundleID: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        domain: String,
        includeSubdomains: Bool = false,
        destinationBundleID: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.domain = domain
        self.includeSubdomains = includeSubdomains
        self.destinationBundleID = destinationBundleID
        self.isEnabled = isEnabled
    }

    /// Whether this rule's domain covers a normalized host, regardless of `isEnabled`.
    public func matches(host: String) -> Bool {
        if host == domain { return true }
        guard includeSubdomains, HostNormalizer.supportsSubdomains(domain), !HostNormalizer.isIPAddress(host) else {
            return false
        }
        return host.hasSuffix("." + domain)
    }

    /// Whether every host this rule matches is also matched by `earlier`, so it can never apply.
    public func isShadowed(by earlier: Rule) -> Bool {
        guard earlier.isEnabled, earlier.matches(host: domain) else { return false }
        let coversSubdomains = includeSubdomains && HostNormalizer.supportsSubdomains(domain)
        return !coversSubdomains || earlier.includeSubdomains && HostNormalizer.supportsSubdomains(earlier.domain)
    }
}

public enum RoutingDecision: Equatable, Sendable {
    case noMatch
    case matched(ruleID: UUID, destinationBundleID: String)
}

public enum RuleEvaluator {
    /// First enabled rule in list order wins. Destination availability is checked separately.
    public static func evaluate(host: String, rules: [Rule]) -> RoutingDecision {
        guard !host.isEmpty else { return .noMatch }
        for rule in rules where rule.isEnabled && rule.matches(host: host) {
            return .matched(ruleID: rule.id, destinationBundleID: rule.destinationBundleID)
        }
        return .noMatch
    }

    /// The first earlier enabled rule that makes `rule` unreachable, if any.
    public static func shadowingRule(for rule: Rule, in rules: [Rule]) -> Rule? {
        for earlier in rules {
            if earlier.id == rule.id { return nil }
            if rule.isShadowed(by: earlier) { return earlier }
        }
        return nil
    }
}
