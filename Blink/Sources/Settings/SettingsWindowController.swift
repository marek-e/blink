import AppKit
import SwiftUI

enum SettingsTab: Int {
    case general, browsers, rules
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    struct Actions {
        var openLink: () -> Void
        var showWelcome: () -> Void
        var quit: () -> Void
    }

    private let model: AppModel
    private let tabs = NSTabViewController()

    init(model: AppModel, actions: Actions) {
        self.model = model
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.allowUserInteraction]

        func tab(_ label: String, symbol: String, _ view: some View) -> NSTabViewItem {
            let host = NSHostingController(rootView: view.saveFailureAlert(model.preferences))
            host.sizingOptions = [.preferredContentSize]
            host.title = label
            let item = NSTabViewItem(viewController: host)
            item.label = label
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            return item
        }
        tabs.addTabViewItem(tab("General", symbol: "gearshape", GeneralSettingsView(model: model, actions: actions)))
        tabs.addTabViewItem(tab("Browsers", symbol: "macwindow.on.rectangle", BrowsersSettingsView(model: model)))
        tabs.addTabViewItem(tab("Rules", symbol: "arrow.triangle.branch", RulesSettingsView(model: model)))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("BlinkSettings")
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func show(tab: SettingsTab?) {
        if let tab { tabs.selectedTabViewItemIndex = tab.rawValue }
        model.refreshBrowsers()
        model.system.refresh()
        NSApp.activate()
        if window?.isVisible != true { window?.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refreshBrowsers()
        model.system.refresh()
    }
}

extension View {
    /// Explains a failed save and offers to retry it. The previous settings remain in effect.
    func saveFailureAlert(_ preferences: Preferences) -> some View {
        modifier(SaveFailureAlert(preferences: preferences))
    }
}

private struct SaveFailureAlert: ViewModifier {
    @Bindable var preferences: Preferences

    func body(content: Content) -> some View {
        content.alert(
            "Blink couldn't save your settings",
            isPresented: Binding(
                get: { preferences.saveFailure != nil },
                set: { if !$0 { preferences.saveFailure = nil } }
            ),
            presenting: preferences.saveFailure
        ) { failure in
            Button("Try Again") { preferences.retry(failure) }
            Button("OK", role: .cancel) { preferences.saveFailure = nil }
        } message: { _ in
            Text("Your previous settings are still in effect. Check that there is free disk space and that Blink can write to its Application Support folder.")
        }
    }
}
