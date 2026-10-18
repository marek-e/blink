import AppKit
import BlinkCore
import Observation
import ServiceManagement

/// Default-browser and login-item status, always read back from the system rather than remembered.
@MainActor
@Observable
final class SystemIntegration {
    private(set) var httpHandlerID: String?
    private(set) var httpsHandlerID: String?
    private(set) var otherHandlerName: String?
    private(set) var isChangingDefault = false
    /// Set when the last default-browser request was declined or failed.
    private(set) var defaultChangeFailed = false

    private(set) var loginStatus: SMAppService.Status = .notRegistered
    private(set) var loginError: String?

    private var blinkID: String? { Bundle.main.bundleIdentifier }

    var defaultBrowserState: DefaultBrowserState {
        DefaultBrowserState(httpHandlerID: httpHandlerID, httpsHandlerID: httpsHandlerID, blinkID: blinkID)
    }

    var launchesAtLogin: Bool { loginStatus == .enabled }

    private var loginStatusName: String {
        switch loginStatus {
        case .enabled: "enabled"
        case .requiresApproval: "requires approval"
        case .notRegistered: "not registered"
        case .notFound: "not found"
        @unknown default: "unknown"
        }
    }
    var loginNeedsApproval: Bool { loginStatus == .requiresApproval }

    func refresh() {
        let http = Self.handler(for: "http")
        let https = Self.handler(for: "https")
        httpHandlerID = http?.bundleID
        httpsHandlerID = https?.bundleID
        otherHandlerName = [http, https].compactMap { $0 }.first { $0.bundleID != blinkID }?.name
        loginStatus = SMAppService.mainApp.status
    }

    /// Asks macOS to make Blink the handler for HTTP, then HTTPS if it isn't already.
    /// macOS asks the user to confirm; declining leaves everything unchanged.
    func makeBlinkDefault() async {
        guard !isChangingDefault else { return }
        isChangingDefault = true
        defaultChangeFailed = false
        defer {
            isChangingDefault = false
            refresh()
        }
        for scheme in ["http", "https"] {
            refresh()
            if Self.handler(for: scheme)?.bundleID == blinkID { continue }
            do {
                try await Self.setDefaultHandler(scheme: scheme)
            } catch {
                Log.system.notice("Default handler change not completed: \(error.sanitizedCode, privacy: .public)")
                defaultChangeFailed = true
                return
            }
        }
    }

    /// Opens the System Settings pane that lists the default web browser.
    func openDefaultBrowserSettings() {
        let pane = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!
        if !NSWorkspace.shared.open(pane) {
            NSWorkspace.shared.open(URL(filePath: "/System/Applications/System Settings.app"))
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            Log.system.error("Login item change failed: \(error.sanitizedCode, privacy: .public)")
            loginError = enabled
                ? "Blink couldn't be added to your login items."
                : "Blink couldn't be removed from your login items."
        }
        refresh()
        Log.system.info("Login item status after change: \(self.loginStatusName, privacy: .public)")
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Opens Privacy & Security › Automation, where Blink's permission to control browsers lives.
    static func openAutomationSettings() {
        let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        if !NSWorkspace.shared.open(pane) {
            NSWorkspace.shared.open(URL(filePath: "/System/Applications/System Settings.app"))
        }
    }

    private static func handler(for scheme: String) -> (bundleID: String?, name: String)? {
        guard let probe = URL(string: "\(scheme)://example.com"),
              let url = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards])
        return (Bundle(url: url)?.bundleIdentifier, name)
    }

    private static func setDefaultHandler(scheme: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
