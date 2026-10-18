import AppKit
import BlinkCore
import Observation
import UniformTypeIdentifiers

/// Installed applications that can open web links, discovered through Launch Services.
@MainActor
@Observable
final class BrowserCatalog: BrowserLocating {
    static let webSchemes = ["http", "https"]

    /// Installed web handlers other than Blink, sorted by name.
    private(set) var browsers: [DiscoveredBrowser] = []

    @ObservationIgnored private var icons: [String: NSImage] = [:]
    /// Names seen this session, so a browser removed while Blink runs keeps a readable name.
    @ObservationIgnored private var seenNames: [String: String] = [:]

    private static let wellKnownNames = [
        "company.thebrowser.Browser": "Arc",
        "company.thebrowser.dia": "Dia",
        "com.google.Chrome": "Google Chrome",
        "app.zen-browser.zen": "Zen",
        "com.apple.Safari": "Safari",
        "com.brave.Browser": "Brave Browser",
        "org.mozilla.firefox": "Firefox",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "com.operasoftware.Opera": "Opera",
        "com.kagi.kagimacOS": "Orion",
        "org.chromium.Chromium": "Chromium",
        "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
    ]

    func refresh() {
        let pageViewers = Set(NSWorkspace.shared.urlsForApplications(toOpen: .html).compactMap { Bundle(url: $0)?.bundleIdentifier })
        var found: [String: DiscoveredBrowser] = [:]
        for scheme in Self.webSchemes {
            for applicationURL in Self.handlers(for: scheme) {
                guard let bundleID = Bundle(url: applicationURL)?.bundleIdentifier, !Self.isBlink(bundleID, applicationURL) else {
                    continue
                }
                if found[bundleID] != nil {
                    found[bundleID]?.schemes.insert(scheme)
                    continue
                }
                // Duplicate installs share a bundle ID; use the copy macOS currently resolves.
                let resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) ?? applicationURL
                let name = FileManager.default.displayName(atPath: resolvedURL.path)
                    .replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards])
                found[bundleID] = DiscoveredBrowser(
                    bundleID: bundleID, name: name, applicationURL: resolvedURL, schemes: [scheme],
                    opensWebPages: pageViewers.contains(bundleID)
                )
            }
        }
        let sorted = found.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for browser in sorted { seenNames[browser.bundleID] = browser.name }
        if sorted != browsers { browsers = sorted }
    }

    func browser(withID bundleID: String) -> DiscoveredBrowser? {
        browsers.first { $0.bundleID == bundleID }
    }

    var availableIDs: Set<String> { Set(browsers.map(\.bundleID)) }

    func name(for bundleID: String) -> String {
        browser(withID: bundleID)?.name ?? seenNames[bundleID] ?? Self.wellKnownNames[bundleID] ?? bundleID
    }

    func icon(for bundleID: String) -> NSImage {
        if let icon = icons[bundleID] { return icon }
        guard let browser = browser(withID: bundleID) else {
            return NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        let icon = NSWorkspace.shared.icon(forFile: browser.applicationURL.path)
        icon.size = NSSize(width: 64, height: 64)
        icons[bundleID] = icon
        return icon
    }

    // MARK: BrowserLocating

    /// Checks Launch Services again at dispatch time rather than trusting the cached list.
    func applicationURL(forBundleID bundleID: String, scheme: String) -> URL? {
        guard bundleID != Bundle.main.bundleIdentifier else { return nil }
        let schemes = scheme == "file" ? Self.webSchemes : [scheme]
        for webScheme in schemes {
            let eligible = Self.handlers(for: webScheme).contains { Bundle(url: $0)?.bundleIdentifier == bundleID }
            if eligible, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
               !Self.isBlink(bundleID, url) {
                return url
            }
        }
        return nil
    }

    private static func handlers(for scheme: String) -> [URL] {
        guard let probe = URL(string: "\(scheme)://example.com") else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: probe)
    }

    private static func isBlink(_ bundleID: String, _ url: URL) -> Bool {
        bundleID == Bundle.main.bundleIdentifier
            || url.standardizedFileURL.resolvingSymlinksInPath() == Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
    }
}
