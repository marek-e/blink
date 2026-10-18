import Foundation

public struct Rule: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var domain: String
    public var includeSubdomains: Bool
    /// Canonical path prefix from `RulePath.normalize`, or empty to match any path.
    public var pathPrefix: String
    public var destination: Destination
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        domain: String,
        includeSubdomains: Bool = false,
        pathPrefix: String = "",
        destination: Destination,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.domain = domain
        self.includeSubdomains = includeSubdomains
        self.pathPrefix = pathPrefix
        self.destination = destination
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, domain, includeSubdomains, pathPrefix, destination, isEnabled
        /// Schema version 1 stored only the browser.
        case destinationBundleID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        domain = try container.decode(String.self, forKey: .domain)
        includeSubdomains = try container.decode(Bool.self, forKey: .includeSubdomains)
        pathPrefix = try container.decodeIfPresent(String.self, forKey: .pathPrefix) ?? ""
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
        if !pathPrefix.isEmpty { try container.encode(pathPrefix, forKey: .pathPrefix) }
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

    /// Whether this rule covers a normalized host and a link's path, regardless of `isEnabled`.
    public func matches(host: String, pathSegments: [String]) -> Bool {
        matches(host: host) && pathSegments.starts(with: prefixSegments)
    }

    /// Whether every link this rule matches is also matched by `earlier`, so it can never apply.
    public func isShadowed(by earlier: Rule) -> Bool {
        guard earlier.isEnabled, earlier.matches(host: domain), prefixSegments.starts(with: earlier.prefixSegments) else {
            return false
        }
        let coversSubdomains = includeSubdomains && HostNormalizer.supportsSubdomains(domain)
        return !coversSubdomains || earlier.includeSubdomains && HostNormalizer.supportsSubdomains(earlier.domain)
    }

    /// The domain followed by the path prefix, as people see the rule.
    public var displayName: String { domain + pathPrefix }

    private var prefixSegments: [String] { RulePath.segments(ofEncodedPath: pathPrefix) }
}

public enum RoutingDecision: Equatable, Sendable {
    case noMatch
    case matched(ruleID: UUID, destination: Destination)
}

public enum RuleEvaluator {
    /// First enabled rule in list order wins. Destination availability is checked separately.
    /// - Parameter path: the link's percent-encoded path.
    public static func evaluate(host: String, path: String, rules: [Rule]) -> RoutingDecision {
        guard !host.isEmpty else { return .noMatch }
        let segments = RulePath.segments(ofEncodedPath: path)
        for rule in rules where rule.isEnabled && rule.matches(host: host, pathSegments: segments) {
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

/// Path prefixes for rules. Paths are compared segment by segment, so `/team` covers `/team` and
/// `/team/page` but not `/teams`. Segments are percent-decoded and compared without regard to case,
/// since many sites (GitHub among them) ignore it; empty segments from repeated or trailing slashes
/// are ignored.
public enum RulePath {
    /// The decoded, lowercased, non-empty segments of a URL's percent-encoded path, for comparison.
    public static func segments(ofEncodedPath path: String) -> [String] {
        path.split(separator: "/").map { ($0.removingPercentEncoding ?? String($0)).lowercased() }
    }

    /// Converts user-entered path text into a canonical prefix: segments re-encoded the same way
    /// every time and joined by single slashes after a leading one, or empty when the text matches
    /// every path.
    ///
    /// Outer whitespace is trimmed and a missing leading slash is added. Queries, fragments,
    /// wildcards, inner whitespace, and encodings that can't be compared reliably are rejected.
    public static func normalize(_ input: String) -> Result<String, RulePathError> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("://") { return .failure(.includesScheme) }
        if text.contains(where: { "?#".contains($0) }) { return .failure(.includesQuery) }
        if text.contains("*") { return .failure(.includesWildcard) }
        if text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return .failure(.includesWhitespace)
        }
        if text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) || text.contains("\\") {
            return .failure(.invalidCharacters)
        }

        var segments: [String] = []
        for encoded in text.split(separator: "/") {
            guard let segment = encoded.removingPercentEncoding,
                  !segment.contains("/"),
                  !segment.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  let canonical = segment.addingPercentEncoding(withAllowedCharacters: segmentCharacters)
            else { return .failure(.invalidCharacters) }
            segments.append(canonical)
        }
        return .success(segments.isEmpty ? "" : "/" + segments.joined(separator: "/"))
    }

    private static let segmentCharacters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
}

public enum RulePathError: Error, Equatable, Sendable {
    case includesScheme
    case includesQuery
    case includesWildcard
    case includesWhitespace
    case invalidCharacters

    public var message: String {
        switch self {
        case .includesScheme: "Enter only the path, such as /team. Put the domain in the Domain field."
        case .includesQuery: "Paths can't include a query or fragment."
        case .includesWildcard: "Wildcards aren't supported. A path also matches everything below it."
        case .includesWhitespace: "Paths can't contain spaces."
        case .invalidCharacters: "This path contains characters Blink can't match."
        }
    }
}
