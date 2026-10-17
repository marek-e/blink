import AppKit

/// Blink runs as a menu bar app, so this menu is never shown. It still routes standard key
/// equivalents (Copy, Paste, Close, Quit) to Blink's windows.
enum MainMenu {
    @MainActor
    static func make(target: AppDelegate) -> NSMenu {
        let main = NSMenu()

        let app = NSMenu(title: "Blink")
        app.addItem(item("About Blink", #selector(AppDelegate.showAboutAction(_:)), target: target))
        app.addItem(.separator())
        app.addItem(item("Settings…", #selector(AppDelegate.showSettingsAction(_:)), key: ",", target: target))
        app.addItem(item("Open Link…", #selector(AppDelegate.showOpenLinkAction(_:)), key: "l", target: target))
        app.addItem(.separator())
        app.addItem(item("Hide Blink", #selector(NSApplication.hide(_:)), key: "h"))
        app.addItem(item("Quit Blink", #selector(NSApplication.terminate(_:)), key: "q"))
        add(app, to: main)

        let edit = NSMenu(title: "Edit")
        edit.addItem(item("Undo", Selector(("undo:")), key: "z"))
        edit.addItem(item("Redo", Selector(("redo:")), key: "Z"))
        edit.addItem(.separator())
        edit.addItem(item("Cut", #selector(NSText.cut(_:)), key: "x"))
        edit.addItem(item("Copy", #selector(NSText.copy(_:)), key: "c"))
        edit.addItem(item("Paste", #selector(NSText.paste(_:)), key: "v"))
        edit.addItem(item("Select All", #selector(NSText.selectAll(_:)), key: "a"))
        add(edit, to: main)

        let window = NSMenu(title: "Window")
        window.addItem(item("Close", #selector(NSWindow.performClose(_:)), key: "w"))
        window.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        add(window, to: main)
        NSApp.windowsMenu = window

        return main
    }

    @MainActor
    private static func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }

    @MainActor
    private static func add(_ submenu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        main.addItem(item)
    }
}
