import Foundation
import Testing
@testable import BlinkCore

private func browser(_ id: String, _ name: String, schemes: Set<String> = ["http", "https"], opensWebPages: Bool = true) -> DiscoveredBrowser {
    DiscoveredBrowser(
        bundleID: id, name: name, applicationURL: URL(filePath: "/Applications/\(name).app"),
        schemes: schemes, opensWebPages: opensWebPages
    )
}

@Suite("Configuration")
struct ConfigurationTests {
    @Test func mergesNewBrowsersInNameOrderAndKeepsMissingOnes() {
        var configuration = Configuration(browsers: [BrowserPreference(bundleID: "gone", isVisible: false)])
        let changed = configuration.mergeDiscovered([
            browser("z", "zen"), browser("a", "Arc"), browser("s", "Safari"), browser("a", "Arc copy"),
        ])
        #expect(changed)
        #expect(configuration.browsers.map(\.bundleID) == ["gone", "a", "s", "z"])
        let addedAreVisible = configuration.browsers.dropFirst().allSatisfy(\.isVisible)
        #expect(addedAreVisible)
        let changedAgain = configuration.mergeDiscovered([browser("s", "Safari")])
        #expect(!changedAgain)
    }

    @Test func appsThatOnlyClaimLinksStartHidden() {
        var configuration = Configuration()
        configuration.mergeDiscovered([browser("chat", "Chat", opensWebPages: false), browser("s", "Safari")])
        #expect(configuration.browsers == [
            BrowserPreference(bundleID: "chat", isVisible: false),
            BrowserPreference(bundleID: "s", isVisible: true),
        ])
    }

    @Test func neverLeavesThePickerEmptyBecauseOfTheBrowserHeuristic() {
        var configuration = Configuration(browsers: [BrowserPreference(bundleID: "gone")])
        configuration.mergeDiscovered([browser("chat", "Chat", opensWebPages: false)])
        #expect(configuration.browsers.last == BrowserPreference(bundleID: "chat", isVisible: true))

        var userHidden = Configuration(browsers: [BrowserPreference(bundleID: "s", isVisible: false)])
        userHidden.mergeDiscovered([browser("s", "Safari"), browser("chat", "Chat", opensWebPages: false)])
        #expect(userHidden.browsers == [
            BrowserPreference(bundleID: "s", isVisible: false),
            BrowserPreference(bundleID: "chat", isVisible: true),
        ])
    }

    @Test func reinstalledBrowserKeepsItsPreferences() {
        var configuration = Configuration(browsers: [
            BrowserPreference(bundleID: "a", isVisible: true),
            BrowserPreference(bundleID: "b", isVisible: false),
        ])
        configuration.mergeDiscovered([browser("a", "A")])
        configuration.mergeDiscovered([browser("a", "A"), browser("b", "B")])
        #expect(configuration.browsers == [
            BrowserPreference(bundleID: "a", isVisible: true),
            BrowserPreference(bundleID: "b", isVisible: false),
        ])
    }

    @Test func pickerChoicesFollowOrderAndVisibility() {
        let configuration = Configuration(browsers: [
            BrowserPreference(bundleID: "c"),
            BrowserPreference(bundleID: "missing"),
            BrowserPreference(bundleID: "hidden", isVisible: false),
            BrowserPreference(bundleID: "a"),
        ])
        let choices = configuration.pickerChoices(from: [browser("a", "A"), browser("hidden", "H"), browser("c", "C")])
        #expect(choices.map(\.bundleID) == ["c", "a"])
    }

    @Test func refusesToHideTheLastAvailableVisibleBrowser() {
        let configuration = Configuration(browsers: [
            BrowserPreference(bundleID: "a"),
            BrowserPreference(bundleID: "missing"),
            BrowserPreference(bundleID: "b", isVisible: false),
        ])
        #expect(!configuration.canHide("a", available: ["a", "b"]))
        #expect(configuration.canHide("missing", available: ["a", "b"]))
        var two = configuration
        two.setVisibility(true, for: "b")
        #expect(two.canHide("a", available: ["a", "b"]))
    }

    @Test func reordersBrowsersAndRules() {
        var configuration = Configuration(browsers: [BrowserPreference(bundleID: "a"), BrowserPreference(bundleID: "b")])
        configuration.moveBrowser("b", by: -1)
        #expect(configuration.browsers.map(\.bundleID) == ["b", "a"])
        configuration.moveBrowser("b", by: -1)
        #expect(configuration.browsers.map(\.bundleID) == ["b", "a"])

        let first = Rule(domain: "a.test", destination: .init(bundleID: "a"))
        let second = Rule(domain: "b.test", destination: .init(bundleID: "b"))
        configuration.rules = [first, second]
        configuration.moveRule(first.id, by: 1)
        #expect(configuration.rules == [second, first])
        var edited = first
        edited.isEnabled = false
        configuration.upsertRule(edited)
        #expect(configuration.rules == [second, edited])
        configuration.deleteRule(second.id)
        #expect(configuration.rules == [edited])
    }

    @Test func validation() {
        #expect(throws: Never.self) { try Configuration().validate() }

        var duplicateBrowser = Configuration(browsers: [BrowserPreference(bundleID: "a"), BrowserPreference(bundleID: "a")])
        #expect(throws: ConfigurationError.self) { try duplicateBrowser.validate() }
        duplicateBrowser.browsers = [BrowserPreference(bundleID: "")]
        #expect(throws: ConfigurationError.self) { try duplicateBrowser.validate() }

        let rule = Rule(domain: "example.com", destination: .init(bundleID: "a"))
        #expect(throws: ConfigurationError.self) { try Configuration(rules: [rule, rule]).validate() }
        #expect(throws: ConfigurationError.self) {
            try Configuration(rules: [Rule(domain: "Example.com", destination: .init(bundleID: "a"))]).validate()
        }
        #expect(throws: ConfigurationError.self) {
            try Configuration(rules: [Rule(domain: "example.com", destination: .init(bundleID: ""))]).validate()
        }
        #expect(throws: ConfigurationError.invalid("non-canonical rule path")) {
            try Configuration(rules: [Rule(domain: "example.com", pathPrefix: "/team/", destination: .init(bundleID: "a"))]).validate()
        }

        var newer = Configuration()
        newer.schemaVersion = 4
        #expect(throws: ConfigurationError.unsupportedVersion(4)) { try newer.validate() }
    }
}

@Suite("Configuration store")
struct ConfigurationStoreTests {
    let directory: URL
    let fileURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "BlinkTests-\(UUID().uuidString)")
        fileURL = directory.appending(path: "nested/configuration.json")
    }

    private func write(_ text: String) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: fileURL)
    }

    private func contents() throws -> String {
        try String(contentsOf: fileURL, encoding: .utf8)
    }

    @Test func missingFileIsFirstRun() {
        let store = ConfigurationStore(fileURL: fileURL)
        #expect(store.load() == .firstRun)
        #expect(!store.isReadOnly)
    }

    @Test func roundTripsAndMatchesDocumentedSchema() throws {
        let store = ConfigurationStore(fileURL: fileURL)
        let rule = Rule(domain: "example.com", includeSubdomains: true, destination: .init(bundleID: "com.apple.Safari"))
        let configuration = Configuration(
            onboardingCompleted: true,
            showsMenuBarIcon: false,
            browsers: [BrowserPreference(bundleID: "com.apple.Safari", isVisible: false)],
            rules: [rule]
        )
        try store.save(configuration)
        #expect(ConfigurationStore(fileURL: fileURL).load() == .loaded(configuration))

        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        #expect(Set(json.keys) == ["schemaVersion", "onboardingCompleted", "showsMenuBarIcon", "browsers", "rules"])
        #expect(json["showsMenuBarIcon"] as? Bool == false)
        let savedRule = try #require((json["rules"] as? [[String: Any]])?.first)
        #expect(Set(savedRule.keys) == ["id", "domain", "includeSubdomains", "destination", "isEnabled"])
        #expect(savedRule["id"] as? String == rule.id.uuidString)
    }

    @Test func pathPrefixesRoundTrip() throws {
        let store = ConfigurationStore(fileURL: fileURL)
        let rule = Rule(domain: "github.com", pathPrefix: "/hublo", destination: .init(bundleID: "company.thebrowser.Browser"))
        let configuration = Configuration(rules: [rule])
        try store.save(configuration)
        #expect(ConfigurationStore(fileURL: fileURL).load() == .loaded(configuration))

        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 3)
        let savedRule = try #require((json["rules"] as? [[String: Any]])?.first)
        #expect(savedRule["pathPrefix"] as? String == "/hublo")
    }

    @Test func upgradesVersionTwoFiles() throws {
        try write("""
        {
          "schemaVersion": 2,
          "onboardingCompleted": true,
          "browsers": [],
          "rules": [{
            "id": "7D3AD686-228B-4A39-B316-E55D476C78E2",
            "domain": "example.com",
            "includeSubdomains": false,
            "destination": { "bundleID": "com.apple.Safari" },
            "isEnabled": true
          }]
        }
        """)
        guard case let .loaded(configuration) = ConfigurationStore(fileURL: fileURL).load() else {
            Issue.record("expected loaded configuration")
            return
        }
        #expect(configuration.schemaVersion == 3)
        #expect(configuration.rules.first?.pathPrefix == "")
    }

    @Test func loadsDocumentedExample() throws {
        try write("""
        {
          "schemaVersion": 1,
          "onboardingCompleted": false,
          "browsers": [{ "bundleID": "com.apple.Safari", "isVisible": true }],
          "rules": [{
            "id": "7D3AD686-228B-4A39-B316-E55D476C78E2",
            "domain": "example.com",
            "includeSubdomains": false,
            "destinationBundleID": "com.apple.Safari",
            "isEnabled": true
          }]
        }
        """)
        guard case let .loaded(configuration) = ConfigurationStore(fileURL: fileURL).load() else {
            Issue.record("expected loaded configuration")
            return
        }
        #expect(configuration.rules.first?.domain == "example.com")
        // Files written before the menu bar setting existed keep showing the icon.
        #expect(configuration.showsMenuBarIcon)
    }

    @Test(arguments: [
        "not json",
        "{}",
        #"{"schemaVersion": 1}"#,
        #"{"schemaVersion": 1, "onboardingCompleted": false, "browsers": [], "rules": [{"id": "x"}]}"#,
        #"{"schemaVersion": 0, "onboardingCompleted": false, "browsers": [], "rules": []}"#,
        #"{"schemaVersion": 1, "onboardingCompleted": false, "browsers": [], "rules": [{"id": "7D3AD686-228B-4A39-B316-E55D476C78E2", "domain": "*.example.com", "includeSubdomains": false, "destinationBundleID": "a", "isEnabled": true}]}"#,
    ])
    func invalidFilesEnterReadOnlyRecoveryAndAreNeverOverwritten(text: String) throws {
        try write(text)
        let store = ConfigurationStore(fileURL: fileURL)
        guard case .recovery(.invalid) = store.load() else {
            Issue.record("expected invalid recovery")
            return
        }
        #expect(store.isReadOnly)
        #expect(throws: ConfigurationStore.SaveError.readOnlyRecovery) { try store.save(Configuration()) }
        #expect(try contents() == text)
    }

    @Test func newerSchemaIsPreserved() throws {
        let text = #"{"schemaVersion": 7, "somethingNew": true}"#
        try write(text)
        let store = ConfigurationStore(fileURL: fileURL)
        #expect(store.load() == .recovery(.unsupportedVersion(7)))
        #expect(throws: ConfigurationStore.SaveError.readOnlyRecovery) { try store.save(Configuration()) }
        #expect(try contents() == text)
    }

    @Test func resetBacksUpOriginalAndLeavesRecovery() throws {
        let text = "corrupt"
        try write(text)
        let store = ConfigurationStore(fileURL: fileURL)
        _ = store.load()
        let backup = try #require(try store.reset(to: Configuration()))
        #expect(try String(contentsOf: backup, encoding: .utf8) == text)
        #expect(!store.isReadOnly)
        #expect(store.load() == .loaded(Configuration()))
        try store.save(Configuration(onboardingCompleted: true))
        #expect(store.load() == .loaded(Configuration(onboardingCompleted: true)))
    }

    @Test func interruptedWriteLeavesOriginalIntact() throws {
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(Configuration(onboardingCompleted: true))
        // A stray temporary file from an interrupted write must not affect loading.
        try Data("{partial".utf8).write(to: fileURL.deletingLastPathComponent().appending(path: ".configuration-stale.tmp"))
        #expect(store.load() == .loaded(Configuration(onboardingCompleted: true)))
    }

    @Test func writeFailureReportsErrorAndKeepsPreviousFile() throws {
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(Configuration(onboardingCompleted: true))
        let before = try contents()
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path) }

        #expect(throws: ConfigurationStore.SaveError.writeFailed) { try store.save(Configuration()) }
        #expect(try contents() == before)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(leftovers == ["configuration.json"])
    }

    @Test func refusesToSaveInvalidConfiguration() throws {
        let store = ConfigurationStore(fileURL: fileURL)
        let invalid = Configuration(browsers: [BrowserPreference(bundleID: "a"), BrowserPreference(bundleID: "a")])
        #expect(throws: ConfigurationStore.SaveError.writeFailed) { try store.save(invalid) }
        #expect(store.load() == .firstRun)
    }
}

@Suite("Default browser state")
struct DefaultBrowserStateTests {
    @Test func derivesStateFromBothSchemes() {
        #expect(DefaultBrowserState(httpHandlerID: "blink", httpsHandlerID: "blink", blinkID: "blink") == .blink)
        #expect(DefaultBrowserState(httpHandlerID: "blink", httpsHandlerID: "arc", blinkID: "blink") == .partial(http: true, https: false))
        #expect(DefaultBrowserState(httpHandlerID: nil, httpsHandlerID: "blink", blinkID: "blink") == .partial(http: false, https: true))
        #expect(DefaultBrowserState(httpHandlerID: "arc", httpsHandlerID: "arc", blinkID: "blink") == .other)
        #expect(DefaultBrowserState(httpHandlerID: nil, httpsHandlerID: nil, blinkID: nil) == .other)
    }
}
