import Foundation
import Observation

public struct OpenRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let link: ValidatedLink

    public init(id: UUID = UUID(), link: ValidatedLink) {
        self.id = id
        self.link = link
    }
}

public enum RequestFailure: Equatable, Sendable {
    /// The chosen or rule-matched browser isn't installed or can't open this kind of link.
    case destinationUnavailable(bundleID: String)
    /// macOS did not accept the request to open the link in this browser.
    case launchFailed(bundleID: String)

    public var bundleID: String {
        switch self {
        case let .destinationUnavailable(bundleID), let .launchFailed(bundleID): bundleID
        }
    }
}

public enum RequestPhase: Equatable, Sendable {
    case choosing
    case dispatching(bundleID: String)
    case failed(RequestFailure)
}

public struct ActiveRequest: Equatable, Sendable {
    public let request: OpenRequest
    public internal(set) var phase: RequestPhase
    /// The rule that matched when the request became active, if any.
    public let matchedRuleID: UUID?
    /// False only while a rule-matched request is dispatching without needing the picker.
    public internal(set) var needsPicker: Bool
    /// Set when macOS hasn't answered a dispatch for a while, for example because the browser is
    /// starting slowly or waiting on a prompt. The user can then see it and cancel.
    public internal(set) var isSlow = false
    var attemptID: UUID?
}

public enum RequestOutcome: Equatable, Sendable {
    case opened(bundleID: String)
    case cancelled
    case discarded
}

@MainActor
public protocol BrowserLocating: AnyObject {
    /// The application to use for `bundleID`, or nil if it's missing or can't open `scheme`.
    func applicationURL(forBundleID bundleID: String, scheme: String) -> URL?
}

@MainActor
public protocol LinkOpening: AnyObject {
    /// Asks macOS to open `url` in a specific application. `completion` reports whether it was accepted.
    /// - Parameter activates: whether the application should come to the front. False while more
    ///   links are waiting, so Blink keeps focus for the next picker.
    func open(_ url: URL, withApplicationAt applicationURL: URL, activates: Bool, completion: @escaping @MainActor (Bool) -> Void)
}

/// Owns the in-memory request queue and every request state transition.
///
/// One request is active at a time. Routing configuration is read when a request becomes
/// active; destination availability is rechecked at every dispatch. Errors never trigger
/// automatic fallback or retry.
@MainActor
@Observable
public final class RequestCoordinator {
    public private(set) var active: ActiveRequest?
    public private(set) var queued: [OpenRequest] = []

    /// While paused (during onboarding), requests queue but none becomes active.
    public var isPaused = false {
        didSet { activateNextIfIdle() }
    }

    @ObservationIgnored public var onFinish: ((OpenRequest, RequestOutcome) -> Void)?

    @ObservationIgnored private let locator: any BrowserLocating
    @ObservationIgnored private let opener: any LinkOpening
    @ObservationIgnored private let rules: @MainActor () -> [Rule]
    @ObservationIgnored private let slowDispatchAfter: Duration

    public init(
        locator: any BrowserLocating,
        opener: any LinkOpening,
        slowDispatchAfter: Duration = .seconds(10),
        rules: @escaping @MainActor () -> [Rule]
    ) {
        self.locator = locator
        self.opener = opener
        self.slowDispatchAfter = slowDispatchAfter
        self.rules = rules
    }

    public var pendingCount: Int { queued.count + (active == nil ? 0 : 1) }

    @discardableResult
    public func enqueue(_ link: ValidatedLink) -> OpenRequest {
        let request = OpenRequest(link: link)
        queued.append(request)
        activateNextIfIdle()
        return request
    }

    /// Dispatches the active request to `bundleID`. Ignored unless the request is choosing or failed.
    @discardableResult
    public func choose(bundleID: String) -> Bool {
        guard var current = active else { return false }
        switch current.phase {
        case .choosing, .failed: break
        case .dispatching: return false
        }

        let link = current.request.link
        guard let applicationURL = locator.applicationURL(forBundleID: bundleID, scheme: link.scheme) else {
            current.phase = .failed(.destinationUnavailable(bundleID: bundleID))
            current.needsPicker = true
            current.attemptID = nil
            active = current
            return false
        }

        let attemptID = UUID()
        let requestID = current.request.id
        current.phase = .dispatching(bundleID: bundleID)
        current.attemptID = attemptID
        current.isSlow = false
        active = current
        let delay = slowDispatchAfter
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.markSlow(requestID: requestID, attemptID: attemptID)
        }
        opener.open(link.url, withApplicationAt: applicationURL, activates: queued.isEmpty) { [weak self] accepted in
            self?.finishDispatch(requestID: requestID, attemptID: attemptID, bundleID: bundleID, accepted: accepted)
        }
        return true
    }

    /// Retries the browser that failed. Only valid after a failure.
    @discardableResult
    public func retry() -> Bool {
        guard case let .failed(failure)? = active?.phase else { return false }
        return choose(bundleID: failure.bundleID)
    }

    /// Cancels the active request and moves to the next. Ignored while a dispatch is in flight,
    /// unless it has become slow; a late answer for a cancelled request is then ignored.
    public func cancelActive() {
        guard let current = active else { return }
        if case .dispatching = current.phase, !current.isSlow { return }
        finish(current.request, .cancelled)
    }

    /// Drops every pending request, including one being dispatched. Used when quitting.
    public func discardAll() {
        let dropped = (active.map { [$0.request] } ?? []) + queued
        active = nil
        queued.removeAll()
        for request in dropped { onFinish?(request, .discarded) }
    }

    private func markSlow(requestID: UUID, attemptID: UUID) {
        guard var current = active, current.request.id == requestID, current.attemptID == attemptID,
              case .dispatching = current.phase
        else { return }
        current.isSlow = true
        current.needsPicker = true
        active = current
    }

    private func finishDispatch(requestID: UUID, attemptID: UUID, bundleID: String, accepted: Bool) {
        guard var current = active, current.request.id == requestID, current.attemptID == attemptID else {
            return
        }
        if accepted {
            finish(current.request, .opened(bundleID: bundleID))
        } else {
            current.phase = .failed(.launchFailed(bundleID: bundleID))
            current.needsPicker = true
            current.attemptID = nil
            active = current
        }
    }

    private func finish(_ request: OpenRequest, _ outcome: RequestOutcome) {
        active = nil
        onFinish?(request, outcome)
        activateNextIfIdle()
    }

    private func activateNextIfIdle() {
        guard active == nil, !isPaused, !queued.isEmpty else { return }
        let request = queued.removeFirst()

        switch RuleEvaluator.evaluate(host: request.link.host, rules: rules()) {
        case .noMatch:
            active = ActiveRequest(request: request, phase: .choosing, matchedRuleID: nil, needsPicker: true)
        case let .matched(ruleID, bundleID):
            active = ActiveRequest(request: request, phase: .choosing, matchedRuleID: ruleID, needsPicker: false)
            choose(bundleID: bundleID)
        }
    }
}
