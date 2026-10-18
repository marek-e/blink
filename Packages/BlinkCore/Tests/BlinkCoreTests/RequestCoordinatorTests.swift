import Foundation
import Testing
@testable import BlinkCore

@MainActor
final class FakeLocator: BrowserLocating {
    var installed: [String: Set<String>] = [:]

    func applicationURL(forBundleID bundleID: String, scheme: String) -> URL? {
        guard installed[bundleID]?.contains(scheme) == true else { return nil }
        return URL(filePath: "/Applications/\(bundleID).app")
    }
}

@MainActor
final class FakeOpener: LinkOpening {
    struct Call {
        let url: URL
        let destination: Destination
        let applicationURL: URL
        let activates: Bool
        let completion: @MainActor (DispatchResult) -> Void
    }

    var calls: [Call] = []
    /// When set, completes each dispatch immediately with this value.
    var autoComplete: DispatchResult?

    func open(
        _ url: URL,
        in destination: Destination,
        withApplicationAt applicationURL: URL,
        activates: Bool,
        completion: @escaping @MainActor (DispatchResult) -> Void
    ) {
        calls.append(Call(url: url, destination: destination, applicationURL: applicationURL, activates: activates, completion: completion))
        if let autoComplete { completion(autoComplete) }
    }
}

@MainActor
@Suite("Request coordinator")
struct RequestCoordinatorTests {
    let locator = FakeLocator()
    let opener = FakeOpener()

    init() {
        locator.installed = ["safari": ["http", "https", "file"], "zen": ["http", "https"]]
    }

    private func makeCoordinator(rules: [Rule] = [], slowAfter: Duration = .seconds(3600)) -> (RequestCoordinator, Box) {
        let box = Box()
        box.rules = rules
        let coordinator = RequestCoordinator(locator: locator, opener: opener, slowDispatchAfter: slowAfter, rules: { box.rules })
        coordinator.onFinish = { request, outcome in box.outcomes.append((request.id, outcome)) }
        return (coordinator, box)
    }

    final class Box {
        var rules: [Rule] = []
        var outcomes: [(UUID, RequestOutcome)] = []
    }

    private func link(_ text: String) -> ValidatedLink {
        try! LinkValidator.validate(text: text).get()
    }

    @Test func processesRequestsInOrderOneAtATime() {
        let (coordinator, box) = makeCoordinator()
        let first = coordinator.enqueue(link("https://example.com/1"))
        let second = coordinator.enqueue(link("https://example.com/1"))
        #expect(first.id != second.id)
        #expect(coordinator.active?.request == first)
        #expect(coordinator.active?.phase == .choosing)
        #expect(coordinator.active?.needsPicker == true)
        #expect(coordinator.queued == [second])
        #expect(coordinator.pendingCount == 2)

        #expect(coordinator.choose(bundleID: "safari"))
        #expect(coordinator.active?.phase == .dispatching(.init(bundleID: "safari")))
        opener.calls[0].completion(.accepted)
        #expect(box.outcomes.map(\.0) == [first.id])
        #expect(coordinator.active?.request == second)
        #expect(coordinator.queued.isEmpty)
    }

    @Test func browserComesForwardOnlyWhenNoLinksAreWaiting() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue(link("https://example.com/1"))
        coordinator.enqueue(link("https://example.com/2"))
        coordinator.choose(bundleID: "safari")
        #expect(opener.calls[0].activates == false)
        opener.calls[0].completion(.accepted)
        coordinator.choose(bundleID: "safari")
        #expect(opener.calls[1].activates == true)
    }

    @Test func dispatchSendsTheOriginalURLToTheExplicitApplication() {
        let (coordinator, _) = makeCoordinator()
        let url = "https://Example.com:8443/path?token=test#fragment"
        coordinator.enqueue(link(url))
        coordinator.choose(bundleID: "zen")
        #expect(opener.calls.count == 1)
        #expect(opener.calls[0].url.absoluteString == url)
        #expect(opener.calls[0].applicationURL.path == "/Applications/zen.app")
    }

    @Test func doubleSelectionDispatchesOnce() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue(link("https://example.com"))
        #expect(coordinator.choose(bundleID: "safari"))
        #expect(!coordinator.choose(bundleID: "safari"))
        #expect(!coordinator.choose(bundleID: "zen"))
        #expect(opener.calls.count == 1)
    }

    @Test func cancelAffectsOnlyTheActiveRequest() {
        let (coordinator, box) = makeCoordinator()
        let first = coordinator.enqueue(link("https://example.com/a"))
        let second = coordinator.enqueue(link("https://example.com/b"))
        coordinator.cancelActive()
        #expect(box.outcomes.count == 1)
        #expect(box.outcomes[0].0 == first.id)
        #expect(box.outcomes[0].1 == .cancelled)
        #expect(coordinator.active?.request == second)
        coordinator.cancelActive()
        #expect(coordinator.active == nil)
        coordinator.cancelActive()
        #expect(box.outcomes.count == 2)
    }

    @Test func cancelIsIgnoredWhileDispatching() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue(link("https://example.com"))
        coordinator.choose(bundleID: "safari")
        coordinator.cancelActive()
        #expect(box.outcomes.isEmpty)
        #expect(coordinator.active?.phase == .dispatching(.init(bundleID: "safari")))
    }

    @Test func launchFailureKeepsRequestAndNeedsExplicitRetry() {
        let (coordinator, box) = makeCoordinator()
        let request = coordinator.enqueue(link("https://example.com"))
        coordinator.choose(bundleID: "safari")
        opener.calls[0].completion(.rejected)
        #expect(coordinator.active?.request == request)
        #expect(coordinator.active?.phase == .failed(.launchFailed(.init(bundleID: "safari"))))
        #expect(opener.calls.count == 1)
        #expect(box.outcomes.isEmpty)

        #expect(coordinator.retry())
        #expect(opener.calls.count == 2)
        #expect(opener.calls[1].applicationURL.path == "/Applications/safari.app")
        opener.calls[1].completion(.accepted)
        #expect(box.outcomes.map(\.1) == [.opened(.init(bundleID: "safari"))])
    }

    @Test func failedRequestCanUseAnotherBrowser() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue(link("https://example.com"))
        coordinator.choose(bundleID: "safari")
        opener.calls[0].completion(.rejected)
        coordinator.choose(bundleID: "zen")
        opener.calls[1].completion(.accepted)
        #expect(box.outcomes.map(\.1) == [.opened(.init(bundleID: "zen"))])
    }

    @Test func staleCompletionsAreIgnored() {
        let (coordinator, box) = makeCoordinator()
        let first = coordinator.enqueue(link("https://example.com/1"))
        coordinator.choose(bundleID: "safari")
        opener.calls[0].completion(.rejected)
        coordinator.retry()
        // The first attempt reports again: it belongs to an old attempt and must not complete the request.
        opener.calls[0].completion(.accepted)
        #expect(box.outcomes.isEmpty)
        #expect(coordinator.active?.request == first)
        opener.calls[1].completion(.accepted)
        opener.calls[1].completion(.accepted)
        #expect(box.outcomes.count == 1)
    }

    @Test func missingBrowserFailsWithoutDispatching() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue(link("https://example.com"))
        #expect(!coordinator.choose(bundleID: "arc"))
        #expect(coordinator.active?.phase == .failed(.destinationUnavailable(.init(bundleID: "arc"))))
        #expect(opener.calls.isEmpty)
        #expect(!coordinator.retry())
    }

    @Test func availabilityIsCheckedPerScheme() {
        let (coordinator, _) = makeCoordinator()
        coordinator.enqueue(.init(url: URL(filePath: "/tmp/a.html"), kind: .file, host: ""))
        #expect(!coordinator.choose(bundleID: "zen"))
        #expect(coordinator.choose(bundleID: "safari"))
    }

    @Test func matchingRuleDispatchesWithoutPicker() {
        let rule = Rule(domain: "example.com", includeSubdomains: true, destination: .init(bundleID: "zen"))
        let (coordinator, box) = makeCoordinator(rules: [rule])
        coordinator.enqueue(link("https://docs.example.com/x"))
        #expect(coordinator.active?.needsPicker == false)
        #expect(coordinator.active?.matchedRuleID == rule.id)
        #expect(coordinator.active?.phase == .dispatching(.init(bundleID: "zen")))
        opener.calls[0].completion(.accepted)
        #expect(box.outcomes.map(\.1) == [.opened(.init(bundleID: "zen"))])
    }

    @Test func unavailableRuleDestinationNeverFallsThrough() {
        let first = Rule(domain: "example.com", destination: .init(bundleID: "arc"))
        let second = Rule(domain: "example.com", destination: .init(bundleID: "safari"))
        let (coordinator, _) = makeCoordinator(rules: [first, second])
        coordinator.enqueue(link("https://example.com"))
        #expect(coordinator.active?.phase == .failed(.destinationUnavailable(.init(bundleID: "arc"))))
        #expect(coordinator.active?.needsPicker == true)
        #expect(coordinator.active?.matchedRuleID == first.id)
        #expect(opener.calls.isEmpty)
    }

    @Test func ruleLaunchFailureShowsRecovery() {
        let (coordinator, _) = makeCoordinator(rules: [Rule(domain: "example.com", destination: .init(bundleID: "zen"))])
        coordinator.enqueue(link("https://example.com"))
        opener.calls[0].completion(.rejected)
        #expect(coordinator.active?.phase == .failed(.launchFailed(.init(bundleID: "zen"))))
        #expect(coordinator.active?.needsPicker == true)
        #expect(opener.calls.count == 1)
    }

    @Test func rulesAreReadWhenRequestBecomesActive() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue(link("https://example.com/1"))
        coordinator.enqueue(link("https://example.com/2"))
        box.rules = [Rule(domain: "example.com", destination: .init(bundleID: "zen"))]
        #expect(coordinator.active?.phase == .choosing)
        coordinator.cancelActive()
        #expect(coordinator.active?.phase == .dispatching(.init(bundleID: "zen")))
    }

    @Test func synchronousCompletionsDrainTheQueue() {
        opener.autoComplete = .accepted
        let (coordinator, box) = makeCoordinator(rules: [Rule(domain: "example.com", destination: .init(bundleID: "zen"))])
        for index in 0..<5 { coordinator.enqueue(link("https://example.com/\(index)")) }
        #expect(coordinator.pendingCount == 0)
        #expect(box.outcomes.count == 5)
        #expect(opener.calls.map(\.url.lastPathComponent) == ["0", "1", "2", "3", "4"])
    }

    @Test func slowDispatchBecomesVisibleAndCancellable() async throws {
        let (coordinator, box) = makeCoordinator(
            rules: [Rule(domain: "example.com", destination: .init(bundleID: "zen"))],
            slowAfter: .milliseconds(20)
        )
        let stuck = coordinator.enqueue(link("https://example.com/1"))
        let next = coordinator.enqueue(link("https://example.org/2"))
        #expect(coordinator.active?.needsPicker == false)
        coordinator.cancelActive()
        #expect(coordinator.active?.request == stuck)

        try await Task.sleep(for: .milliseconds(200))
        #expect(coordinator.active?.isSlow == true)
        #expect(coordinator.active?.needsPicker == true)
        #expect(!coordinator.choose(bundleID: "safari"))

        coordinator.cancelActive()
        #expect(box.outcomes.map(\.1) == [.cancelled])
        #expect(coordinator.active?.request == next)
        // The browser finally answers for the cancelled request: ignored.
        opener.calls[0].completion(.accepted)
        #expect(box.outcomes.count == 1)
    }

    @Test func fastDispatchNeverBecomesSlow() async throws {
        let (coordinator, box) = makeCoordinator(slowAfter: .milliseconds(20))
        coordinator.enqueue(link("https://example.com"))
        coordinator.choose(bundleID: "safari")
        opener.calls[0].completion(.accepted)
        try await Task.sleep(for: .milliseconds(100))
        #expect(coordinator.active == nil)
        #expect(box.outcomes.count == 1)
    }

    @Test func pausingHoldsRequestsUntilResumed() {
        let (coordinator, _) = makeCoordinator()
        coordinator.isPaused = true
        let request = coordinator.enqueue(link("https://example.com"))
        #expect(coordinator.active == nil)
        #expect(coordinator.pendingCount == 1)
        coordinator.isPaused = false
        #expect(coordinator.active?.request == request)
    }

    @Test func discardAllDropsEverythingAndIgnoresLateCallbacks() {
        let (coordinator, box) = makeCoordinator()
        coordinator.enqueue(link("https://example.com/1"))
        coordinator.enqueue(link("https://example.com/2"))
        coordinator.choose(bundleID: "safari")
        coordinator.discardAll()
        #expect(coordinator.pendingCount == 0)
        #expect(box.outcomes.map(\.1) == [.discarded, .discarded])
        opener.calls[0].completion(.accepted)
        #expect(box.outcomes.count == 2)
        #expect(coordinator.active == nil)
    }
}
