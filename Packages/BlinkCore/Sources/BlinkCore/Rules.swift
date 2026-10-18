import Foundation

public struct Rule: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var domain: String
    public var includeSubdomains: Bool
    public var destination: Destination
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        domain: String,
        includeSubdomains: Bool = false,
        destination: Destination,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.domain = domain
        self.includeSubdomains = includeSubdomains
        self.destination = destination
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, domain, includeSubdomains, destination, isEnabled
        /// Schema version 1 stored only the browser.
        case destinationBundleID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        domain = try container.decode(String.self, forKey: .domain)
        includeSubdomains = try container.decode(Bool.self, forKey: .includeSubdomains)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        if let destination = try container.decodeIfPresent(Destination.self, forKey: .destination) {
            self.destination = destination
        } else {
            destination = Destination(bundleID: try container.decode(String.self, forKey: .destinationBundleID))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(domain, forKey: .domain)
        try container.encode(includeSubdomains, forKey: .includeSubdomains)
        try container.encode(destination, forKey: .destination)
        try container.encode(isEnabled, forKey: .isEnabled)
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
    case matched(ruleID: UUID, destination: Destination)
}

public enum RuleEvaluator {
    /// First enabled rule in list order wins. Destination availability is checked separately.
    public static func evaluate(host: String, rules: [Rule]) -> RoutingDecision {
        guard !host.isEmpty else { return .noMatch }
        for rule in rules where rule.isEnabled && rule.matches(host: host) {
            return .matched(ruleID: rule.id, destination: rule.destination)
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
