import Foundation

/// A validated URL that Blink can route. The original URL is kept unchanged for dispatch.
public struct ValidatedLink: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// An absolute HTTP or HTTPS URL.
        case web
        /// A local document handed to Blink by macOS while it is the default browser.
        case file
    }

    public let url: URL
    public let kind: Kind
    /// Normalized comparison host for web links; empty for files.
    public let host: String

    public var scheme: String { kind == .file ? "file" : url.scheme!.lowercased() }

    /// The percent-encoded path rules compare against; empty for files.
    public var encodedPath: String {
        guard kind == .web else { return "" }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
    }
}

public enum LinkRejection: Error, Equatable, Sendable {
    case malformed
    case unsupportedScheme
    case missingHost
    case unsupportedHost
    case includesCredentials
    case controlCharacters

    public var message: String {
        switch self {
        case .malformed: "Enter a complete link that starts with http:// or https://."
        case .unsupportedScheme: "Blink opens HTTP and HTTPS links only."
        case .missingHost: "This link has no website address."
        case .unsupportedHost: "This link's website address isn't valid."
        case .includesCredentials: "Blink doesn't open links that contain a user name or password."
        case .controlCharacters: "This link contains invalid characters."
        }
    }
}

public enum LinkValidator {
    /// Validates text typed or pasted by the user. Only web links are accepted.
    public static func validate(text: String) -> Result<ValidatedLink, LinkRejection> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return .failure(.controlCharacters)
        }
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return .failure(.malformed) }
        return validate(url, allowFiles: false)
    }

    /// Validates a URL delivered to Blink.
    ///
    /// Local files are accepted only when `allowFiles` is set, because macOS may hand HTML
    /// documents to the default browser.
    public static func validate(_ url: URL, allowFiles: Bool = true) -> Result<ValidatedLink, LinkRejection> {
        let absolute = url.absoluteString
        if absolute.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return .failure(.controlCharacters)
        }
        guard let scheme = url.scheme?.lowercased() else { return .failure(.malformed) }

        if scheme == "file" {
            guard allowFiles else { return .failure(.unsupportedScheme) }
            guard url.isFileURL, !url.path.isEmpty, url.path != "/" else { return .failure(.malformed) }
            return .success(ValidatedLink(url: url, kind: .file, host: ""))
        }
        guard scheme == "http" || scheme == "https" else { return .failure(.unsupportedScheme) }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.malformed)
        }
        if components.percentEncodedUser != nil || components.percentEncodedPassword != nil {
            return .failure(.includesCredentials)
        }
        guard let encodedHost = components.encodedHost, !encodedHost.isEmpty else {
            return .failure(.missingHost)
        }
        guard let host = HostNormalizer.normalizedHost(of: components) else {
            return .failure(.unsupportedHost)
        }
        return .success(ValidatedLink(url: url, kind: .web, host: host))
    }
}

/// Display helpers that avoid exposing query values in the default picker preview.
public enum LinkPreview {
    /// Scheme, host, port, and path, with any query or fragment replaced by an ellipsis marker.
    public static func summary(of link: ValidatedLink) -> String {
        if link.kind == .file { return link.url.path }
        guard let components = URLComponents(url: link.url, resolvingAgainstBaseURL: false) else {
            return link.host
        }
        var text = "\(link.url.scheme!.lowercased())://\(link.host)"
        if let port = components.port { text += ":\(port)" }
        let path = components.percentEncodedPath
        if !path.isEmpty, path != "/" { text += path }
        if components.percentEncodedQuery != nil { text += "?…" }
        if components.percentEncodedFragment != nil { text += "#…" }
        return text
    }

    /// The prominent title for a request: the ASCII host, or the file name.
    public static func title(of link: ValidatedLink) -> String {
        link.kind == .file ? link.url.lastPathComponent : link.host
    }
}
