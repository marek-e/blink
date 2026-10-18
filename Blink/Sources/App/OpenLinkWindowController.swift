import AppKit
import BlinkCore
import SwiftUI

/// Accepts a pasted link and sends it through the normal routing pipeline, so Blink can be
/// tried before it becomes the default browser.
@MainActor
final class OpenLinkWindowController: NSWindowController {
    init(model: AppModel) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        panel.title = "Open Link"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        super.init(window: panel)
        let host = NSHostingController(rootView: OpenLinkView(model: model) { [weak panel] in panel?.close() })
        host.sizingOptions = [.preferredContentSize]
        panel.contentViewController = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func show() {
        NSApp.activate()
        if window?.isVisible != true {
            window?.center()
            // A new hosting controller gives the view new state, so the text and error reset
            // and the field takes focus again. Reassigning rootView would keep the old @State.
            if let old = window?.contentViewController as? NSHostingController<OpenLinkView> {
                let host = NSHostingController(rootView: OpenLinkView(model: old.rootView.model, close: old.rootView.close))
                host.sizingOptions = [.preferredContentSize]
                window?.contentViewController = host
            }
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct OpenLinkView: View {
    let model: AppModel
    let close: () -> Void

    @State private var text = ""
    @State private var rejection: LinkRejection?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Link", text: $text, prompt: Text("https://example.com"))
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(open)
                .onChange(of: text) { rejection = nil }
                .accessibilityLabel("Link to open")
            if let rejection {
                Label(rejection.message, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .onAppear { Announcer.announce(rejection.message) }
            } else {
                Text("Blink handles this link exactly as if you'd clicked it in another app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: close)
                    .keyboardShortcut(.cancelAction)
                Button("Open", action: open)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func open() {
        if let rejection = model.open(text: text) {
            self.rejection = rejection
        } else {
            text = ""
            close()
        }
    }
}

/// Shows `AppModel.notices` one at a time, such as links macOS delivered that Blink can't open.
@MainActor
final class NoticePresenter {
    private let model: AppModel
    private var isPresenting = false

    init(model: AppModel) {
        self.model = model
        observeContinuously { [weak self] in self?.sync() }
    }

    private func sync() {
        guard let notice = model.notices.first, !isPresenting else { return }
        isPresenting = true
        // Present outside the current Apple event so further links keep arriving.
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = notice.title
            alert.informativeText = notice.message
            alert.addButton(withTitle: "OK")
            NSApp.activate()
            alert.runModal()
            isPresenting = false
            model.dismissNotice(notice)
        }
    }
}
