import AppKit
import BlinkCore

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: StatusItemController?
    private var picker: PickerPanelController?
    private var settings: SettingsWindowController?
    private var onboarding: OnboardingWindowController?
    private var openLink: OpenLinkWindowController?
    private var notices: NoticePresenter?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    // Links delivered at cold launch can arrive before `applicationDidFinishLaunching`,
    // so the model is ready from `applicationWillFinishLaunching`.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "Blink"
        var fileURL = ConfigurationStore.defaultFileURL(bundleID: bundleID)
        #if DEBUG || BLINK_TESTING
        // Lets manual testing use a scratch file: `open Blink.app --args -BlinkConfigurationPath /tmp/x.json`.
        if let path = UserDefaults.standard.string(forKey: "BlinkConfigurationPath") {
            fileURL = URL(filePath: path)
        }
        #endif
        let store = ConfigurationStore(fileURL: fileURL)
        model = AppModel(preferences: Preferences(store: store))
        NSApp.mainMenu = MainMenu.make(target: self)
        #if DEBUG || BLINK_TESTING
        DebugSnapshots.install()
        // Lets UI review cover both appearances: `-BlinkAppearance light` or `dark`.
        switch UserDefaults.standard.string(forKey: "BlinkAppearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        picker = PickerPanelController(model: model) { [weak self] tab in self?.showSettings(tab: tab) }
        notices = NoticePresenter(model: model)
        statusItem = StatusItemController(model: model, actions: .init(
            openLink: { [weak self] in self?.showOpenLink() },
            settings: { [weak self] in self?.showSettings() },
            about: { [weak self] in self?.showAbout() },
            quit: { NSApp.terminate(nil) }
        ))
        if !model.configuration.onboardingCompleted {
            showOnboarding()
        }
        if model.preferences.loadProblem != nil {
            // Rules don't apply in recovery mode; say so instead of letting links behave differently unexplained.
            showSettings(tab: .general)
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                let showsWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeKey }
                ActivationHandoff.handBackIfIdle(hasVisibleWindows: showsWindow)
                self?.model.system.refresh()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        model.handleDelivered(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if onboarding != nil {
            showOnboarding()
        } else {
            showSettings()
        }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let pending = model.coordinator.pendingCount
        guard pending > 0 else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = pending == 1
            ? "Discard the link that hasn't opened yet?"
            : "Discard \(pending) links that haven't opened yet?"
        alert.informativeText = "Blink doesn't save waiting links. If you quit now, they won't open."
        alert.addButton(withTitle: "Keep Blink Open")
        alert.addButton(withTitle: "Discard and Quit").hasDestructiveAction = true
        NSApp.activate()
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        model.coordinator.discardAll()
        return .terminateNow
    }

    // MARK: Windows

    @objc func showSettingsAction(_ sender: Any?) { showSettings() }
    @objc func showOpenLinkAction(_ sender: Any?) { showOpenLink() }
    @objc func showAboutAction(_ sender: Any?) { showAbout() }

    func showSettings(tab: SettingsTab? = nil) {
        if settings == nil {
            settings = SettingsWindowController(model: model, actions: .init(
                openLink: { [weak self] in self?.showOpenLink() },
                showWelcome: { [weak self] in self?.showOnboarding() },
                quit: { NSApp.terminate(nil) }
            ))
        }
        settings?.show(tab: tab)
    }

    func showOpenLink() {
        if openLink == nil { openLink = OpenLinkWindowController(model: model) }
        openLink?.show()
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController(model: model) { [weak self] in
                self?.onboarding = nil
            }
        }
        onboarding?.show()
    }

    func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "From link to browser, instantly.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor]
            ),
        ])
    }
}
