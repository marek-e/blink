import AppKit
import BlinkCore

/// Opens links in an explicitly chosen application. Never falls back to the system default handler,
/// which may be Blink itself.
@MainActor
final class WorkspaceOpener: LinkOpening {
    func open(_ url: URL, withApplicationAt applicationURL: URL, activates: Bool, completion: @escaping @MainActor (Bool) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        // macOS 14+ activation is cooperative: Blink must hand activation over, or the browser
        // opens the link behind whatever is frontmost. While more links wait, Blink keeps focus
        // so the next picker can take keyboard input.
        if activates, let bundleID = Bundle(url: applicationURL)?.bundleIdentifier {
            NSApp.yieldActivation(toApplicationWithBundleIdentifier: bundleID)
        }
        let started = ContinuousClock.now
        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: configuration) { application, error in
            let elapsed = ContinuousClock.now - started
            if let error {
                Log.dispatch.error("Dispatch rejected: \(error.sanitizedCode, privacy: .public)")
            } else {
                Log.dispatch.info("Dispatch accepted in \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public)")
            }
            let accepted = error == nil
            Task { @MainActor in
                if activates, let application { ActivationHandoff.bringForward(application) }
                completion(accepted)
            }
        }
    }
}

/// Makes sure the browser that received a link ends up in front of Blink.
///
/// macOS activates Blink when it delivers a link, and that activation can land after a rule has
/// already dispatched the link. If Blink becomes active with nothing to show right after a
/// dispatch, it hands activation back to that browser.
@MainActor
enum ActivationHandoff {
    private static var recent: (application: NSRunningApplication, time: ContinuousClock.Instant)?

    static func bringForward(_ application: NSRunningApplication) {
        recent = (application, .now)
        activate(application)
    }

    /// Called when Blink becomes active. Returns whether activation was handed back.
    @discardableResult
    static func handBackIfIdle(hasVisibleWindows: Bool) -> Bool {
        guard let recent, ContinuousClock.now - recent.time < .seconds(2), !hasVisibleWindows,
              !recent.application.isTerminated
        else { return false }
        activate(recent.application)
        return true
    }

    private static func activate(_ application: NSRunningApplication) {
        NSApp.yieldActivation(to: application)
        application.activate(from: .current, options: [])
    }
}
