import AppKit
import BlinkCore
import Observation

@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let catalog: BrowserCatalog
    let profiles = ProfileCatalog()
    let system: SystemIntegration
    let coordinator: RequestCoordinator

    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Messages waiting to be shown one at a time, oldest first.
    private(set) var notices: [Notice] = []

    /// Destinations chosen with "Always open here", by request. The rule is saved only once the link opens.
    @ObservationIgnored private var ruleIntents: [UUID: Destination] = [:]

    /// When each pending request arrived, for latency logging. Memory only; entries are removed when requests finish.
    @ObservationIgnored private var arrivalTimes: [UUID: ContinuousClock.Instant] = [:]

    init(preferences: Preferences) {
        let catalog = BrowserCatalog()
        self.preferences = preferences
        self.catalog = catalog
        system = SystemIntegration()
        coordinator = RequestCoordinator(locator: catalog, opener: WorkspaceOpener()) {
            preferences.configuration.rules
        }
        coordinator.isPaused = !preferences.configuration.onboardingCompleted
        coordinator.onFinish = { [weak self] request, outcome in
            guard let self else { return }
            arrivalTimes[request.id] = nil
            let intended = ruleIntents.removeValue(forKey: request.id)
            switch outcome {
            case let .opened(destination):
                Log.dispatch.info("Request completed")
                if intended == destination { saveAlwaysRule(host: request.link.host, destination: destination) }
            case .cancelled: Log.dispatch.info("Request cancelled")
            case .discarded: Log.dispatch.info("Request discarded")
            }
        }
        refreshBrowsers()
        system.refresh()
    }

    var configuration: Configuration { preferences.configuration }

    var pickerChoices: [DiscoveredBrowser] {
        configuration.pickerChoices(from: catalog.browsers)
    }

    func refreshBrowsers() {
        catalog.refresh()
        preferences.mergeDiscovered(catalog.browsers)
        profiles.refreshInBackground(catalog.browsers.map(\.bundleID))
    }

    // MARK: Requests

    func handleDelivered(_ urls: [URL]) {
        for url in urls {
            switch LinkValidator.validate(url) {
            case let .success(link):
                Log.intake.info("Accepted request")
                let arrival = ContinuousClock.now
                let request = coordinator.enqueue(link)
                // Only requests that go straight to the picker are timed; queued ones also include waiting.
                if let active = coordinator.active, active.request.id == request.id, active.needsPicker {
                    arrivalTimes[request.id] = arrival
                }
            case let .failure(rejection):
                Log.intake.notice("Rejected request: \(String(describing: rejection), privacy: .public)")
                post(Notice(title: "Blink can't open this link", message: rejection.message))
            }
        }
    }

    /// Records how long a request waited between arriving and its picker appearing.
    func logPickerShown(for requestID: UUID) {
        guard let arrival = arrivalTimes.removeValue(forKey: requestID) else { return }
        let elapsed = ContinuousClock.now - arrival
        Log.intake.info("Picker interactive \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public) after arrival")
    }

    /// Validates typed text and queues it. Returns the reason it was refused, if any.
    func open(text: String) -> LinkRejection? {
        switch LinkValidator.validate(text: text) {
        case let .success(link):
            coordinator.enqueue(link)
            return nil
        case let .failure(rejection):
            return rejection
        }
    }

    /// Dispatches the request with `requestID`, if it's still the active one. With `alwaysForHost`,
    /// a rule for the link's host is saved after the browser accepts the link.
    func choose(_ destination: Destination, for requestID: UUID, alwaysForHost: Bool = false) {
        guard let active = coordinator.active, active.request.id == requestID else { return }
        ruleIntents[requestID] = alwaysForHost && canCreateRule(for: active) ? destination : nil
        coordinator.choose(destination)
    }

    /// Points the host's exact rule at `destination`, creating it at the end of the list if needed,
    /// so repeated choices never stack up shadowed duplicates.
    private func saveAlwaysRule(host: String, destination: Destination) {
        guard case let .success(domain) = HostNormalizer.normalizeRuleDomain(host) else { return }
        let saved = preferences.update { configuration in
            if let index = configuration.rules.firstIndex(where: { $0.domain == domain && !$0.includeSubdomains }) {
                configuration.rules[index].destination = destination
                configuration.rules[index].isEnabled = true
            } else {
                configuration.rules.append(Rule(domain: domain, destination: destination))
            }
        }
        if !saved {
            // Report it now; the settings alert would appear later, out of context.
            preferences.saveFailure = nil
            post(Notice(
                title: "Blink couldn't save the rule",
                message: "The link opened, but the rule for \(domain) wasn't saved. You can add it in Settings › Rules."
            ))
        }
    }

    func post(_ notice: Notice) {
        notices.append(notice)
    }

    func dismissNotice(_ notice: Notice) {
        notices.removeAll { $0.id == notice.id }
    }

    /// "Always open here" is offered only for web links that no rule matched, while settings can be saved.
    func canCreateRule(for active: ActiveRequest) -> Bool {
        active.request.link.kind == .web && active.matchedRuleID == nil && !preferences.isReadOnly
    }

    func retry(_ requestID: UUID) {
        guard coordinator.active?.request.id == requestID else { return }
        coordinator.retry()
    }

    func cancel(_ requestID: UUID) {
        guard coordinator.active?.request.id == requestID else { return }
        coordinator.cancelActive()
    }

    func finishOnboarding(openTestLink: Bool) {
        preferences.update { $0.onboardingCompleted = true }
        if openTestLink, case let .success(link) = LinkValidator.validate(text: "https://example.com/") {
            coordinator.enqueue(link)
        }
        coordinator.isPaused = false
    }

    static func copyToPasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        pasteboard.setString(url.absoluteString, forType: .URL)
    }
}
