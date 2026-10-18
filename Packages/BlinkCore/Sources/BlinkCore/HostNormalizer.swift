import Foundation

/// The single normalization shared by incoming link hosts and saved rule domains.
///
/// Hosts are compared in ASCII form: lowercased, internationalized labels converted to
/// punycode by Foundation's IDNA support, and one trailing DNS dot removed. Representations
/// that cannot be compared reliably (percent-encoded hosts, empty labels, unexpected
/// characters) are rejected rather than guessed at.
public enum HostNormalizer {
    public static let maximumHostLength = 253
    public static let maximumLabelLength = 63

    /// Returns the comparison host for parsed URL components, or nil when it is missing or unsupported.
    public static func normalizedHost(of components: URLComponents) -> String? {
        guard let encoded = components.encodedHost, !encoded.isEmpty else { return nil }
        return normalize(encodedHost: encoded)
    }

    static func normalize(encodedHost: String) -> String? {
        var host = encodedHost.lowercased()

        if host.hasPrefix("[") {
            guard host.hasSuffix("]"), host.count > 2 else { return nil }
            let address = host.dropFirst().dropLast()
            let isIPv6 = address.contains(":")
                && address.unicodeScalars.allSatisfy { isHexDigit($0) || $0 == ":" || $0 == "." }
            return isIPv6 ? host : nil
        }

        if host.hasSuffix(".") { host.removeLast() }
        guard !host.isEmpty, host.utf8.count <= maximumHostLength else { return nil }

        for label in host.split(separator: ".", omittingEmptySubsequences: false) {
            guard !label.isEmpty,
                  label.utf8.count <= maximumLabelLength,
                  label.unicodeScalars.allSatisfy(isLabelCharacter)
            else { return nil }
        }
        return host
    }

    /// Whether a normalized host is an IP literal, or numeric like one.
    ///
    /// No real top-level domain is all digits, so any host ending in a numeric label is treated
    /// as an address. This keeps `0.0.1` from matching `10.0.0.1` as a "subdomain".
    public static func isIPAddress(_ host: String) -> Bool {
        if host.hasPrefix("[") { return true }
        guard let last = host.split(separator: ".").last else { return false }
        return last.unicodeScalars.allSatisfy { ("0"..."9").contains($0) }
    }

    /// Whether a rule for this normalized host may also match its subdomains.
    public static func supportsSubdomains(_ host: String) -> Bool {
        !isIPAddress(host) && host.contains(".")
    }

    /// Converts user-entered rule text into a canonical rule domain.
    ///
    /// Accepts a host only. Outer whitespace is trimmed; schemes, ports, paths, wildcards,
    /// credentials, inner whitespace, and empty labels are rejected.
    public static func normalizeRuleDomain(_ input: String) -> Result<String, RuleDomainError> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.empty) }
        if text.contains("://") { return .failure(.includesScheme) }
        if text.contains("@") { return .failure(.includesCredentials) }
        if text.contains("*") { return .failure(.includesWildcard) }
        if text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return .failure(.includesWhitespace)
        }
        if text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return .failure(.invalidCharacters)
        }
        if text.contains(where: { "/?#\\".contains($0) }) { return .failure(.includesPath) }

        let isBracketed = text.hasPrefix("[")
        if isBracketed {
            guard text.hasSuffix("]") else { return .failure(.includesPort) }
        } else if text.contains(":") {
            return .failure(.includesPort)
        }
        if text.contains("%") || text.contains("[") != isBracketed || text.contains("]") != isBracketed {
            return .failure(.invalidCharacters)
        }
        if !isBracketed, text.hasPrefix(".") || text.contains("..") {
            return .failure(.emptyLabel)
        }

        guard let components = URLComponents(string: "https://" + text),
              let host = normalizedHost(of: components)
        else {
            return .failure(text.utf8.count > maximumHostLength ? .tooLong : .invalidCharacters)
        }
        return .success(host)
    }

    private static func isLabelCharacter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-" || scalar == "_"
    }

    private static func isHexDigit(_ scalar: Unicode.Scalar) -> Bool {
        ("0"..."9").contains(scalar) || ("a"..."f").contains(scalar)
    }
}

public enum RuleDomainError: Error, Equatable, Sendable {
    case empty
    case includesScheme
    case includesCredentials
    case includesWildcard
    case includesWhitespace
    case includesPath
    case includesPort
    case emptyLabel
    case invalidCharacters
    case tooLong

    public var message: String {
        switch self {
        case .empty: "Enter a domain, such as example.com."
        case .includesScheme: "Enter only the domain, without http:// or https://."
        case .includesCredentials: "Domains can't include a user name or password."
        case .includesWildcard: "Wildcards aren't supported. Use “Include subdomains” instead."
        case .includesWhitespace: "Domains can't contain spaces."
        case .includesPath: "Enter only the domain. Put a path in the Path field; queries and fragments aren't supported."
        case .includesPort: "Enter only the domain, without a port."
        case .emptyLabel: "Domains can't have empty parts between dots."
        case .invalidCharacters: "This domain contains characters Blink can't match."
        case .tooLong: "This domain is too long."
        }
    }
}
