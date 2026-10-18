import AppKit
import BlinkCore
import Observation
import SwiftUI

/// Per-request picker state shared by the panel's keyboard handling and the SwiftUI view.
@MainActor
@Observable
final class PickerSession {
    private(set) var requestID: UUID?
    var selection = 0
    /// Browsers whose profiles are shown. Reset for every link, like the rest of the picker.
    var expanded: Set<String> = []
    var alwaysForHost = false
    var showsFullLink = false
    /// The tallest the browser list may be before it scrolls, from the screen the picker opens on.
    var maxListHeight: CGFloat = .infinity

    func reset(for requestID: UUID) {
        self.requestID = requestID
        selection = 0
        expanded = []
        alwaysForHost = false
        showsFullLink = false
    }
}

/// Shows the picker whenever the active request needs a choice, and hides it otherwise.
@MainActor
final class PickerPanelController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let panel: PickerPanel
    private let session = PickerSession()
    /// Where the panel's top edge was placed, so it grows downward when profiles are shown.
    private var anchoredTop: CGFloat?

    init(model: AppModel, showSettings: @escaping (SettingsTab) -> Void) {
        self.model = model
        panel = PickerPanel()
        super.init()

        let host = NSHostingController(rootView: PickerContainer(
            model: model,
            session: session,
            choose: { [weak self] index in self?.choose(at: index) },
            showSettings: showSettings
        ))
        host.sizingOptions = [.preferredContentSize]
        // Glass draws its backdrop across the whole view. Clipping keeps the window's shadow on the
        // rounded panel instead of its bounding rectangle.
        host.view.wantsLayer = true
        host.view.layer?.cornerRadius = PickerView.cornerRadius
        host.view.layer?.cornerCurve = .continuous
        host.view.layer?.masksToBounds = true
        panel.contentViewController = host
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.cancelPresented() }
        panel.onCopy = { [weak self] in self?.copyPresented() }
        panel.onKey = { [weak self] key in self?.handle(key) ?? false }

        observeContinuously { [weak self] in self?.sync() }
    }

    private var presented: ActiveRequest? {
        guard let active = model.coordinator.active, active.needsPicker, active.request.id == session.requestID else {
            return nil
        }
        return active
    }

    private func sync() {
        guard let active = model.coordinator.active, active.needsPicker else {
            if panel.isVisible { panel.orderOut(nil) }
            return
        }
        guard session.requestID != active.request.id || !panel.isVisible else { return }

        let isFirst = !panel.isVisible
        session.reset(for: active.request.id)
        model.refreshBrowsers()
        if isFirst {
            session.maxListHeight = WindowPlacement.visibleHeight(nearPointer: NSEvent.mouseLocation) - PickerView.reservedHeight
            panel.layoutIfNeeded()
            panel.setFrame(WindowPlacement.frame(for: panel.frame.size, nearPointer: NSEvent.mouseLocation), display: false)
            anchoredTop = panel.frame.maxY
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        if !NSApp.isActive { panel.orderFrontRegardless() }
        panel.displayIfNeeded()
        model.logPickerShown(for: active.request.id)
        announce(active)
    }

    private func announce(_ active: ActiveRequest) {
        var parts = ["Open \(LinkPreview.title(of: active.request.link))"]
        let count = model.pickerChoices.count
        parts.append(count == 1 ? "1 browser" : "\(count) browsers")
        let waiting = model.coordinator.queued.count
        if waiting > 0 { parts.append(waiting == 1 ? "1 more link waiting" : "\(waiting) more links waiting") }
        Announcer.announce(parts.joined(separator: ". "))
    }

    private var outline: PickerOutline {
        model.pickerOutline(expanded: session.expanded, selection: session.selection)
    }

    private func handle(_ key: PickerKey) -> Bool {
        guard presented != nil else { return false }
        var outline = outline
        switch key {
        case .up, .down:
            outline.move(by: key == .up ? -1 : 1)
        case .expand:
            outline.expandSelection()
        case .collapse:
            outline.collapseSelection()
        case .open:
            choose(at: session.selection)
            return true
        case let .digit(number):
            if let index = outline.index(forShortcut: number) { choose(at: index) }
            return true
        }
        let previous = (session.selection, session.expanded)
        session.expanded = outline.expanded
        session.selection = outline.selection
        if previous != (session.selection, session.expanded), let row = outline.selectedRow {
            Announcer.announce(PickerView.spokenName(of: row, model: model))
        }
        return true
    }

    private func choose(at index: Int) {
        guard let active = presented else { return }
        if case .dispatching = active.phase { return }
        let rows = outline.rows
        guard rows.indices.contains(index) else { return }
        session.selection = index
        model.choose(
            rows[index].destination,
            for: active.request.id,
            alwaysForHost: session.alwaysForHost && model.canCreateRule(for: active)
        )
    }

    private func cancelPresented() {
        guard let active = presented else { return }
        model.cancel(active.request.id)
    }

    private func copyPresented() {
        guard let active = presented else { return }
        AppModel.copyToPasteboard(active.request.link.url)
        Announcer.announce("Link copied")
    }

    func windowDidMove(_ notification: Notification) {
        anchoredTop = panel.frame.maxY
    }

    func windowDidResize(_ notification: Notification) {
        var frame = panel.frame
        if let anchoredTop { frame.origin.y = anchoredTop - frame.height }
        let clamped = WindowPlacement.clamp(frame)
        if clamped != panel.frame { panel.setFrame(clamped, display: true) }
    }
}

// Borderless: a titled full-size-content window makes NSHostingController's size tracking
// fight safe-area updates. The SwiftUI content draws its own rounded material background.
final class PickerPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onCopy: () -> Void = {}
    var onKey: (PickerKey) -> Bool = { _ in false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: PickerView.width, height: 300),
            // Non-activating: the panel takes keyboard focus even when macOS's cooperative activation
            // keeps another app active (for example a browser that just launched itself).
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        title = "Open Link"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        setAccessibilityTitle("Choose a Browser")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Picker keys are handled before controls see them, unless the user is editing text.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           let key = PickerKey(keyCode: event.keyCode, hasCommandModifier: !event.modifierFlags.intersection([.command, .option, .control]).isEmpty),
           !((firstResponder as? NSTextView)?.isEditable ?? false),
           onKey(key) {
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    /// ⌘W cancels, like closing a titled window.
    override func performClose(_ sender: Any?) {
        onCancel()
    }

    /// Copy Link when nothing else (such as selected URL text) handles ⌘C.
    @objc func copy(_ sender: Any?) {
        onCopy()
    }
}

enum WindowPlacement {
    @MainActor
    static func frame(for size: NSSize, nearPointer pointer: NSPoint) -> NSRect {
        PickerPlacement.frame(size: size, pointer: pointer, screens: screens)
    }

    @MainActor
    static func clamp(_ frame: NSRect) -> NSRect {
        let top = NSPoint(x: frame.midX, y: frame.maxY)
        guard let screen = PickerPlacement.screen(containing: top, in: screens) else { return frame }
        return PickerPlacement.clamp(frame, into: screen)
    }

    /// The usable height of the screen under the pointer, inside the placement margin.
    @MainActor
    static func visibleHeight(nearPointer pointer: NSPoint) -> CGFloat {
        guard let screen = PickerPlacement.screen(containing: pointer, in: screens) else { return .infinity }
        return screen.visibleFrame.height - 2 * PickerPlacement.margin
    }

    @MainActor
    private static var screens: [PickerPlacement.Screen] {
        NSScreen.screens.map { PickerPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }
}
