import Foundation
import Testing
@testable import BlinkCore

@Suite("Profile destinations")
struct ProfileDestinationTests {
    let perso = ProfileReference(id: "F7F527B4", name: "Perso")

    @Test func profilesAreEqualByIDAcrossRenames() {
        let renamed = ProfileReference(id: perso.id, name: "Personal")
        #expect(renamed == perso)
        #expect(Set([renamed, perso]).count == 1)
        #expect(Destination(bundleID: "arc", profile: renamed) == Destination(bundleID: "arc", profile: perso))
        #expect(Destination(bundleID: "arc", profile: perso) != Destination(bundleID: "arc"))
    }

    @Test func rulesMatchWithTheirProfile() {
        let rule = Rule(domain: "example.com", destination: Destination(bundleID: "arc", profile: perso))
        #expect(RuleEvaluator.evaluate(host: "example.com", path: "/", rules: [rule])
            == .matched(ruleID: rule.id, destination: Destination(bundleID: "arc", profile: perso)))
    }

    @Test func validationRejectsEmptyProfileID() {
        let rule = Rule(domain: "example.com", destination: Destination(bundleID: "arc", profile: .init(id: "", name: "x")))
        #expect(throws: ConfigurationError.invalid("empty rule profile")) {
            try Configuration(rules: [rule]).validate()
        }
    }

    @Test func hidesAndShowsProfiles() {
        var configuration = Configuration(browsers: [BrowserPreference(bundleID: "arc")])
        configuration.setProfileVisibility(false, profileID: "a", for: "arc")
        configuration.setProfileVisibility(false, profileID: "a", for: "arc")
        #expect(configuration.browsers[0].hiddenProfileIDs == ["a"])
        #expect(configuration.isProfileHidden("a", for: "arc"))
        configuration.setProfileVisibility(true, profileID: "a", for: "arc")
        #expect(!configuration.isProfileHidden("a", for: "arc"))
        #expect(!configuration.isProfileHidden("a", for: "unknown"))
    }
}

@Suite("Configuration schema version 2")
struct ConfigurationSchemaTests {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: "BlinkTests-\(UUID().uuidString)/configuration.json")

    private func write(_ text: String) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: fileURL)
    }

    @Test func upgradesVersionOneFiles() throws {
        try write("""
        {
          "schemaVersion": 1,
          "onboardingCompleted": true,
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
        let store = ConfigurationStore(fileURL: fileURL)
        guard case let .loaded(configuration) = store.load() else {
            Issue.record("expected loaded configuration")
            return
        }
        #expect(configuration.schemaVersion == 3)
        #expect(configuration.rules.first?.destination == Destination(bundleID: "com.apple.Safari"))
        #expect(configuration.browsers.first?.hiddenProfileIDs == [])

        try store.save(configuration)
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 3)
        let rule = try #require((json["rules"] as? [[String: Any]])?.first)
        #expect(rule["destinationBundleID"] == nil)
        #expect((rule["destination"] as? [String: Any])?["bundleID"] as? String == "com.apple.Safari")
    }

    @Test func roundTripsProfiles() throws {
        let profile = ProfileReference(id: "Profile 2", name: "Perso")
        let configuration = Configuration(
            browsers: [BrowserPreference(bundleID: "com.google.Chrome", hiddenProfileIDs: ["Default"])],
            rules: [Rule(domain: "example.com", destination: Destination(bundleID: "com.google.Chrome", profile: profile))]
        )
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(configuration)
        guard case let .loaded(loaded) = ConfigurationStore(fileURL: fileURL).load() else {
            Issue.record("expected loaded configuration")
            return
        }
        #expect(loaded == configuration)
        #expect(loaded.rules[0].destination.profile?.name == "Perso")
        #expect(loaded.browsers[0].hiddenProfileIDs == ["Default"])
    }

    @Test func newerFilesStayUntouched() throws {
        let text = #"{"schemaVersion": 4, "onboardingCompleted": true, "browsers": [], "rules": []}"#
        try write(text)
        let store = ConfigurationStore(fileURL: fileURL)
        #expect(store.load() == .recovery(.unsupportedVersion(4)))
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == text)
    }
}

@MainActor
@Suite("Requests with profiles")
struct ProfileRequestTests {
    let locator = FakeLocator()
    let opener = FakeOpener()
    let arc = Destination(bundleID: "arc", profile: ProfileReference(id: "space-1", name: "Perso"))

    init() {
        locator.installed = ["arc": ["http", "https"]]
    }

    private func makeCoordinator(rules: [Rule] = []) -> (RequestCoordinator, RequestCoordinatorTests.Box) {
        let box = RequestCoordinatorTests.Box()
        box.rules = rules
        let coordinator = RequestCoordinator(locator: locator, opener: opener, slowDispatchAfter: .seconds(3600), rules: { box.rules })
        coordinator.onFinish = { request, outcome in box.outcomes.append((request.id, outcome)) }
        return (coordinator, box)
    }

    private func link() -> ValidatedLink {
        try! LinkValidator.validate(text: "https://example.com/a").get()
    }

    @Test func dispatchesWithTheProfile() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue(link())
        #expect(coordinator.choose(arc))
        #expect(coordinator.active?.phase == .dispatching(arc))
        #expect(opener.calls[0].destination.profile?.id == "space-1")
        opener.calls[0].completion(.accepted)
        #expect(box.outcomes.map(\.1) == [.opened(arc)])
    }

    @Test(arguments: [
        (DispatchResult.profileUnavailable, "profile"),
        (DispatchResult.automationDenied, "automation"),
        (DispatchResult.rejected, "launch"),
    ])
    func mapsDispatchFailures(result: DispatchResult, kind: String) {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue(link())
        coordinator.choose(arc)
        opener.calls[0].completion(result)
        let expected: RequestFailure = switch kind {
        case "profile": .profileUnavailable(arc)
        case "automation": .automationDenied(arc)
        default: .launchFailed(arc)
        }
        #expect(coordinator.active?.phase == .failed(expected))
        #expect(coordinator.active?.needsPicker == true)
    }

    @Test func retryKeepsTheProfile() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue(link())
        coordinator.choose(arc)
        opener.calls[0].completion(.automationDenied)
        #expect(coordinator.retry())
        #expect(opener.calls[1].destination == arc)
    }

    @Test func rulesDispatchWithTheirProfile() {
        let rule = Rule(domain: "example.com", destination: arc)
        let (coordinator, _) = makeCoordinator(rules: [rule])
        coordinator.enqueue(link())
        #expect(coordinator.active?.matchedRuleID == rule.id)
        #expect(coordinator.active?.needsPicker == false)
        #expect(opener.calls[0].destination == arc)
    }
}
