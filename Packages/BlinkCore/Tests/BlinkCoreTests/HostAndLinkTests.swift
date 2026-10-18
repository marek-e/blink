import Foundation
import Testing
@testable import BlinkCore

@Suite("Host normalization")
struct HostNormalizationTests {
    @Test(arguments: [
        ("example.com", "example.com"),
        ("EXAMPLE.com", "example.com"),
        ("Example.COM.", "example.com"),
        ("  example.com\n", "example.com"),
        ("bücher.example", "xn--bcher-kva.example"),
        ("BÜCHER.example", "xn--bcher-kva.example"),
        ("xn--bcher-kva.example", "xn--bcher-kva.example"),
        ("例え.テスト", "xn--r8jz45g.xn--zckzah"),
        ("192.168.0.1", "192.168.0.1"),
        ("[::1]", "[::1]"),
        ("[2001:DB8::1]", "[2001:db8::1]"),
        ("localhost", "localhost"),
        ("_service.example.com", "_service.example.com"),
    ])
    func acceptsRuleDomains(input: String, expected: String) {
        #expect(HostNormalizer.normalizeRuleDomain(input) == .success(expected))
    }

    @Test(arguments: [
        ("", RuleDomainError.empty),
        ("   ", .empty),
        ("https://example.com", .includesScheme),
        ("user@example.com", .includesCredentials),
        ("*.example.com", .includesWildcard),
        ("exa mple.com", .includesWhitespace),
        ("example.com/path", .includesPath),
        ("example.com?q=1", .includesPath),
        ("example.com#top", .includesPath),
        ("example.com:8080", .includesPort),
        ("[::1]:80", .includesPort),
        (".example.com", .emptyLabel),
        ("a..example.com", .emptyLabel),
        ("example.com..", .emptyLabel),
        ("ex%41mple.com", .invalidCharacters),
        ("exa!mple.com", .invalidCharacters),
        ("[nothex]", .invalidCharacters),
        ("example\u{0007}.com", .invalidCharacters),
        (String(repeating: "a.", count: 130) + "com", .tooLong),
    ])
    func rejectsInvalidRuleDomains(input: String, expected: RuleDomainError) {
        #expect(HostNormalizer.normalizeRuleDomain(input) == .failure(expected))
    }

    @Test func incomingHostsUseTheSameNormalizationAsRules() throws {
        let link = try LinkValidator.validate(text: "https://BÜCHER.Example./a").get()
        let ruleDomain = try HostNormalizer.normalizeRuleDomain("bücher.example").get()
        #expect(link.host == ruleDomain)
    }

    @Test func classifiesHosts() {
        #expect(HostNormalizer.isIPAddress("10.0.0.1"))
        #expect(HostNormalizer.isIPAddress("[::1]"))
        #expect(HostNormalizer.isIPAddress("0.0.1"))
        #expect(!HostNormalizer.isIPAddress("10.0.0.example"))
        #expect(!HostNormalizer.isIPAddress("1password.com"))
        #expect(!HostNormalizer.supportsSubdomains("localhost"))
        #expect(!HostNormalizer.supportsSubdomains("10.0.0.1"))
        #expect(HostNormalizer.supportsSubdomains("example.com"))
    }
}

@Suite("Link intake")
struct LinkValidatorTests {
    @Test(arguments: [
        "https://example.com/path?token=test#fragment",
        "http://example.com:8080/a/b?x=1&y=%20#frag",
        "HTTPS://Example.com",
        "https://[::1]:8443/",
        "https://127.0.0.1/",
        "https://localhost/",
        "https://xn--bcher-kva.example/",
    ])
    func acceptsWebLinksAndPreservesThem(text: String) throws {
        let link = try LinkValidator.validate(text: text).get()
        #expect(link.kind == .web)
        #expect(link.url.absoluteString == text)
    }

    @Test func derivesComparisonHost() throws {
        #expect(try LinkValidator.validate(text: "http://EXAMPLE.com:8080/a").get().host == "example.com")
        #expect(try LinkValidator.validate(text: "https://example.com./").get().host == "example.com")
        #expect(try LinkValidator.validate(text: "https://[::1]:443/").get().host == "[::1]")
    }

    @Test(arguments: [
        ("", LinkRejection.malformed),
        ("example.com", .malformed),
        ("/relative/path", .malformed),
        ("ftp://example.com", .unsupportedScheme),
        ("mailto:someone@example.com", .unsupportedScheme),
        ("javascript:alert(1)", .unsupportedScheme),
        ("file:///tmp/a.html", .unsupportedScheme),
        ("https://", .missingHost),
        ("https:///path", .missingHost),
        ("https://user:pass@example.com", .includesCredentials),
        ("https://user@example.com", .includesCredentials),
        ("https://ex%41mple.com", .unsupportedHost),
        ("https://a..b.example", .unsupportedHost),
    ])
    func rejectsUnsupportedText(text: String, expected: LinkRejection) {
        #expect(LinkValidator.validate(text: text) == .failure(expected))
    }

    @Test func rejectsRawControlCharactersButKeepsEncodedOnes() throws {
        #expect(LinkValidator.validate(text: "https://example.com/a\u{07}b") == .failure(.controlCharacters))
        #expect(LinkValidator.validate(text: "https://exam\u{0}ple.com") == .failure(.controlCharacters))
        let encoded = try LinkValidator.validate(text: "https://example.com/a%0Ab").get()
        #expect(encoded.url.absoluteString == "https://example.com/a%0Ab")
    }

    @Test func acceptsDeliveredFilesOnlyWhenAllowed() throws {
        let file = URL(filePath: "/tmp/page.html")
        #expect(try LinkValidator.validate(file).get().kind == .file)
        #expect(try LinkValidator.validate(file).get().scheme == "file")
        #expect(LinkValidator.validate(file, allowFiles: false) == .failure(.unsupportedScheme))
    }

    @Test func previewHidesQueryAndFragment() throws {
        let link = try LinkValidator.validate(text: "https://Example.com:8443/docs/a?token=secret#part").get()
        #expect(LinkPreview.summary(of: link) == "https://example.com:8443/docs/a?…#…")
        #expect(LinkPreview.title(of: link) == "example.com")
        let bare = try LinkValidator.validate(text: "https://example.com/").get()
        #expect(LinkPreview.summary(of: bare) == "https://example.com")
    }
}
