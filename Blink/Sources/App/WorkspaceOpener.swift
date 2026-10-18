import AppKit
import BlinkCore

/// Opens links in an explicitly chosen application, and profile when the destination names one.
/// Never falls back to the system default handler, which may be Blink itself, or to the browser's
/// default profile when the chosen one is gone.
@MainActor
final class WorkspaceOpener: LinkOpening {
    private let profiles: ProfileCatalog

    init(profiles: ProfileCatalog) {
        self.profiles = profiles
    }

    func open(
        _ url: URL,
        in destination: Destination,
        withApplicationAt applicationURL: URL,
        activates: Bool,
        completion: @escaping @MainActor (DispatchResult) -> Void
    ) {
        guard let profile = destination.profile else {
            openPlain(url, withApplicationAt: applicationURL, activates: activates, completion: completion)
            return
        }
        guard let support = ProfileSupport.forBundleID(destination.bundleID) else {
            completion(.profileUnavailable)
            return
        }
        Task {
            guard let current = await profiles.current(profile, for: destination.bundleID) else {
                Log.dispatch.notice("Dispatch stopped: profile not found")
                completion(.profileUnavailable)
                return
            }
            let started = ContinuousClock.now
            let finish: @MainActor (DispatchResult) -> Void = { result in
                let elapsed = ContinuousClock.now - started
                Log.dispatch.info("Profile dispatch finished in \(elapsed.formatted(.units(allowed: [.milliseconds])), privacy: .public): \(String(describing: result), privacy: .public)")
                if result == .accepted, activates { ActivationHandoff.bringForward(bundleID: destination.bundleID) }
                completion(result)
            }
            if activates { NSApp.yieldActivation(toApplicationWithBundleIdentifier: destination.bundleID) }
            switch support.family {
            case .chromium:
                launch(applicationURL, arguments: ["--profile-directory=\(current.id)", url.absoluteString], activates: activates, completion: finish)
            case .firefox:
                launch(applicationURL, arguments: ["-P", current.name, url.absoluteString], activates: activates, completion: finish)
            case .arc:
                ProfileScript.arc.run(arguments: [current.id, url.absoluteString, activates ? "1" : "0"], completion: finish)
            case .dia:
                ProfileScript.dia.run(arguments: [current.name, url.absoluteString, activates ? "1" : "0"], completion: finish)
            }
        }
    }

    private func openPlain(
        _ url: URL,
        withApplicationAt applicationURL: URL,
        activates: Bool,
        completion: @escaping @MainActor (DispatchResult) -> Void
    ) {
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
                completion(accepted ? .accepted : .rejected)
            }
        }
    }

    /// Starts a new instance of the browser with profile arguments. Chromium and Firefox hand the
    /// link to an instance already running that profile and exit, or start the browser if it's quit.
    private func launch(
        _ applicationURL: URL,
        arguments: [String],
        activates: Bool,
        completion: @escaping @MainActor (DispatchResult) -> Void
    ) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        configuration.createsNewApplicationInstance = true
        configuration.arguments = arguments
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
            if let error { Log.dispatch.error("Profile launch rejected: \(error.sanitizedCode, privacy: .public)") }
            let accepted = error == nil
            Task { @MainActor in completion(accepted ? .accepted : .rejected) }
        }
    }
}

/// AppleScript that opens a link in an Arc space or Dia profile.
///
/// Runs through `osascript` so a cold start, which takes a few seconds, never blocks the main
/// thread. The script text is fixed; the space or profile and the URL are passed as arguments,
/// never spliced into the script.
enum ProfileScript {
    case arc, dia

    private var source: String {
        switch self {
        case .arc:
            """
            on run {spaceID, theURL, shouldActivate}
                tell application id "company.thebrowser.Browser"
                    repeat 50 times
                        if (count of windows) > 0 then exit repeat
                        delay 0.2
                    end repeat
                    if (count of windows) = 0 then make new window
                    tell front window
                        tell space id spaceID
                            make new tab with properties {URL:theURL}
                            focus
                        end tell
                    end tell
                    if shouldActivate is "1" then activate
                end tell
            end run
            """
        case .dia:
            """
            on run {profileName, theURL, shouldActivate}
                tell application id "company.thebrowser.dia"
                    repeat 50 times
                        if (count of windows) > 0 then exit repeat
                        delay 0.2
                    end repeat
                    tell front window
                        set targetProfile to profile profileName
                        tell targetProfile to make new tab with properties {URL:theURL}
                        focus targetProfile
                    end tell
                    if shouldActivate is "1" then activate
                end tell
            end run
            """
        }
    }

    @MainActor
    func run(arguments: [String], completion: @escaping @MainActor (DispatchResult) -> Void) {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = ["-e", source] + arguments
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { process in
            let output = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            let result = Self.result(status: process.terminationStatus, errorOutput: output)
            Task { @MainActor in completion(result) }
        }
        do {
            try process.run()
        } catch {
            Log.dispatch.error("Profile script didn't start: \(error.sanitizedCode, privacy: .public)")
            completion(.rejected)
        }
    }

    /// Maps osascript's exit status and AppleScript error number. The message itself can contain
    /// the URL, so only the number is logged.
    private nonisolated static func result(status: Int32, errorOutput: String) -> DispatchResult {
        guard status != 0 else { return .accepted }
        let code = errorOutput.firstMatch(of: /\((-?\d+)\)\s*$/).map { String($0.1) } ?? "unknown"
        Log.dispatch.error("Profile script failed: \(code, privacy: .public)")
        switch code {
        // errAEEventNotPermitted, and errAEEventWouldRequireUserConsent.
        case "-1743", "-1744": return .automationDenied
        // errAENoSuchObject: the space or profile isn't there.
        case "-1728": return .profileUnavailable
        default: return .rejected
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

    /// For links handed over by a helper process or Apple Events: brings forward the browser's
    /// most recently launched instance that's still running, after the helper has had time to exit.
    static func bringForward(bundleID: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { !$0.isTerminated }
                .max { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
            if let running { bringForward(running) }
        }
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
