import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    struct Actions {
        var openLink: () -> Void
        var settings: () -> Void
        var about: () -> Void
        var quit: () -> Void
    }

    private let model: AppModel
    private let actions: Actions
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(model: AppModel, actions: Actions) {
        self.model = model
        self.actions = actions
        super.init()
        item.button?.image = BlinkGlyph.menuBarImage()
        item.button?.setAccessibilityLabel("Blink")
        item.button?.toolTip = "Blink"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let pending = model.coordinator.pendingCount
        if pending > 0 {
            let waiting = NSMenuItem(title: pending == 1 ? "1 link waiting" : "\(pending) links waiting", action: nil, keyEquivalent: "")
            waiting.isEnabled = false
            menu.addItem(waiting)
            menu.addItem(.separator())
        }
        menu.addItem(menuItem("Open Link…", key: "l", #selector(openLink)))
        menu.addItem(menuItem("Settings…", key: ",", #selector(settings)))
        menu.addItem(.separator())
        menu.addItem(menuItem("About Blink", #selector(about)))
        menu.addItem(menuItem("Quit Blink", key: "q", #selector(quit)))
    }

    private func menuItem(_ title: String, key: String = "", _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openLink() { actions.openLink() }
    @objc private func settings() { actions.settings() }
    @objc private func about() { actions.about() }
    @objc private func quit() { actions.quit() }
}
