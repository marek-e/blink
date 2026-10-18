import Foundation

public struct BrowserPreference: Codable, Hashable, Sendable {
    public var bundleID: String
    public var isVisible: Bool
    /// Profiles left out of the picker, by `ProfileReference.id`.
    public var hiddenProfileIDs: [String]

    public init(bundleID: String, isVisible: Bool = true, hiddenProfileIDs: [String] = []) {
        self.bundleID = bundleID
        self.isVisible = isVisible
        self.hiddenProfileIDs = hiddenProfileIDs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        hiddenProfileIDs = try container.decodeIfPresent([String].self, forKey: .hiddenProfileIDs) ?? []
    }
}

/// A browser found on this Mac. Names, locations, and schemes are runtime data, not identity.
public struct DiscoveredBrowser: Hashable, Sendable {
    public var bundleID: String
    public var name: String
    public var applicationURL: URL
    public var schemes: Set<String>
    /// Whether the app also registers as a viewer for HTML documents. Real browsers do; apps that
    /// only claim web links for their own purposes (chat clients, terminals) usually don't.
    public var opensWebPages: Bool

    public init(bundleID: String, name: String, applicationURL: URL, schemes: Set<String>, opensWebPages: Bool = true) {
        self.bundleID = bundleID
        self.name = name
        self.applicationURL = applicationURL
        self.schemes = schemes
        self.opensWebPages = opensWebPages
    }
}

/// Everything Blink persists. Array order is meaningful: browsers are picker order, rules are precedence.
public struct Configuration: Codable, Equatable, Sendable {
    /// Version 2 added profiles to rule destinations; version 1 files are upgraded when read.
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var onboardingCompleted: Bool
    /// Whether Blink shows its icon in the menu bar. Older files may not have this key.
    public var showsMenuBarIcon: Bool
    public var browsers: [BrowserPreference]
    public var rules: [Rule]

    public init(
        onboardingCompleted: Bool = false,
        showsMenuBarIcon: Bool = true,
        browsers: [BrowserPreference] = [],
        rules: [Rule] = []
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.onboardingCompleted = onboardingCompleted
        self.showsMenuBarIcon = showsMenuBarIcon
        self.browsers = browsers
        self.rules = rules
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        // Version 1 differs only in how rules store their destination, which `Rule` decodes.
        if schemaVersion == 1 { schemaVersion = Self.currentSchemaVersion }
        onboardingCompleted = try container.decode(Bool.self, forKey: .onboardingCompleted)
        showsMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarIcon) ?? true
        browsers = try container.decode([BrowserPreference].self, forKey: .browsers)
        rules = try container.decode([Rule].self, forKey: .rules)
    }

    public func validate() throws(ConfigurationError) {
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw .unsupportedVersion(schemaVersion)
        }
        guard schemaVersion == Self.currentSchemaVersion else { throw .invalid("unknown schema version") }

        var bundleIDs = Set<String>()
        for browser in browsers {
            guard !browser.bundleID.isEmpty else { throw .invalid("empty browser identifier") }
            guard bundleIDs.insert(browser.bundleID).inserted else { throw .invalid("duplicate browser") }
        }
        var ruleIDs = Set<UUID>()
        for rule in rules {
            guard ruleIDs.insert(rule.id).inserted else { throw .invalid("duplicate rule") }
            guard !rule.destination.bundleID.isEmpty else { throw .invalid("empty rule destination") }
            if let profile = rule.destination.profile, profile.id.isEmpty { throw .invalid("empty rule profile") }
            guard case .success(rule.domain) = HostNormalizer.normalizeRuleDomain(rule.domain) else {
                throw .invalid("non-canonical rule domain")
            }
        }
    }

    // MARK: Browsers

    /// Appends newly discovered browsers in localized name order. Saved entries for browsers that
    /// are no longer installed are kept.
    ///
    /// New apps that open web pages start visible. Apps that only claim web links start hidden,
    /// unless that would leave the picker without any available browser.
    /// - Returns: whether anything was added.
    @discardableResult
    public mutating func mergeDiscovered(_ discovered: [DiscoveredBrowser]) -> Bool {
        let known = Set(browsers.map(\.bundleID))
        var seen = Set<String>()
        let additions = discovered
            .filter { !known.contains($0.bundleID) && seen.insert($0.bundleID).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !additions.isEmpty else { return false }

        let firstAddition = browsers.endIndex
        browsers += additions.map { BrowserPreference(bundleID: $0.bundleID, isVisible: $0.opensWebPages) }
        let available = Set(discovered.map(\.bundleID))
        if !browsers.contains(where: { $0.isVisible && available.contains($0.bundleID) }) {
            for index in browsers.indices[firstAddition...] { browsers[index].isVisible = true }
        }
        return true
    }

    /// Picker choices: visible, available browsers in the user's order.
    public func pickerChoices(from available: [DiscoveredBrowser]) -> [DiscoveredBrowser] {
        let byID = Dictionary(available.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })
        return browsers.filter(\.isVisible).compactMap { byID[$0.bundleID] }
    }

    /// Hiding is refused when it would leave no available browser visible in the picker.
    public func canHide(_ bundleID: String, available: Set<String>) -> Bool {
        browsers.contains { $0.bundleID != bundleID && $0.isVisible && available.contains($0.bundleID) }
    }

    public mutating func setVisibility(_ isVisible: Bool, for bundleID: String) {
        guard let index = browsers.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        browsers[index].isVisible = isVisible
    }

    /// Moves a browser one place up (`offset` -1) or down (`offset` 1) in picker order.
    public mutating func moveBrowser(_ bundleID: String, by offset: Int) {
        guard let index = browsers.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        let target = index + offset
        guard browsers.indices.contains(target) else { return }
        browsers.swapAt(index, target)
    }

    public func isProfileHidden(_ profileID: String, for bundleID: String) -> Bool {
        browsers.first { $0.bundleID == bundleID }?.hiddenProfileIDs.contains(profileID) ?? false
    }

    public mutating func setProfileVisibility(_ isVisible: Bool, profileID: String, for bundleID: String) {
        guard let index = browsers.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        browsers[index].hiddenProfileIDs.removeAll { $0 == profileID }
        if !isVisible { browsers[index].hiddenProfileIDs.append(profileID) }
    }

    public mutating func removeBrowser(_ bundleID: String) {
        browsers.removeAll { $0.bundleID == bundleID }
    }

    // MARK: Rules

    public mutating func moveRule(_ id: UUID, by offset: Int) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard rules.indices.contains(target) else { return }
        rules.swapAt(index, target)
    }

    public mutating func upsertRule(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    public mutating func deleteRule(_ id: UUID) {
        rules.removeAll { $0.id == id }
    }
}

public enum ConfigurationError: Error, Equatable, Sendable {
    /// The file was written by a newer Blink.
    case unsupportedVersion(Int)
    /// The file is unreadable or fails validation.
    case invalid(String)
}

/// Whether Blink receives web links, from the handlers macOS reports for each scheme.
public enum DefaultBrowserState: Equatable, Sendable {
    case blink
    /// Only one of the two schemes points at Blink.
    case partial(http: Bool, https: Bool)
    case other

    public init(httpHandlerID: String?, httpsHandlerID: String?, blinkID: String?) {
        let http = blinkID != nil && httpHandlerID == blinkID
        let https = blinkID != nil && httpsHandlerID == blinkID
        switch (http, https) {
        case (true, true): self = .blink
        case (false, false): self = .other
        default: self = .partial(http: http, https: https)
        }
    }
}
