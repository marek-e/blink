import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private let onClose: () -> Void
    private var finished = false

    init(model: AppModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = "Welcome to Blink"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let host = NSHostingController(rootView: OnboardingView(model: model) { [weak self] openTestLink in
            self?.finish(openTestLink: openTestLink)
        })
        host.sizingOptions = [.preferredContentSize]
        window.contentViewController = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func show() {
        NSApp.activate()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Closing the window counts as finishing: waiting links must not stay stuck behind onboarding.
    func windowWillClose(_ notification: Notification) {
        if !finished { model.finishOnboarding(openTestLink: false) }
        onClose()
    }

    private func finish(openTestLink: Bool) {
        finished = true
        model.finishOnboarding(openTestLink: openTestLink)
        close()
    }
}

struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome, browsers, defaultBrowser, login, done
    }

    let model: AppModel
    let finish: (_ openTestLink: Bool) -> Void

    @State private var step = Step.welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var waitingCount: Int { model.coordinator.pendingCount }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .browsers: browsers
                case .defaultBrowser: defaultBrowser
                case .login: login
                case .done: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .transition(reduceMotion ? .identity : .opacity)

            Divider()
            footer
                .padding(16)
        }
        .frame(width: 520, height: 520)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Circle()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            if waitingCount > 0 && step != .welcome && step != .done {
                Label(waitingCount == 1 ? "1 link waiting" : "\(waitingCount) links waiting", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .help("Waiting links open when you finish.")
            }
            Spacer()
            if step != .welcome && step != .done {
                Button("Back") { step = Step(rawValue: step.rawValue - 1) ?? .welcome }
            }
            switch step {
            case .welcome:
                Button("Get Started") { step = .browsers }.keyboardShortcut(.defaultAction)
            case .browsers, .login:
                Button("Continue") { advance() }.keyboardShortcut(.defaultAction)
            case .defaultBrowser:
                Button(model.system.defaultBrowserState == .blink ? "Continue" : "Not Now") { advance() }
                    .keyboardShortcut(.defaultAction)
            case .done:
                Button("Open Test Link") { finish(true) }
                Button("Done") { finish(false) }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private func advance() {
        step = Step(rawValue: step.rawValue + 1) ?? .done
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("Choose where your links open.")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Blink asks which browser to use when you open a link from another app, or sends it straight to the right one using rules you set.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if waitingCount > 0 {
                waitingNote
            }
        }
        .padding(.top, 20)
    }

    private var browsers: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Arrange your browsers", "This is the order the picker shows them in. Uncheck any app you don't want to see; you can change this later in Settings.")
            BrowserPreferencesList(model: model)
                .frame(height: 260)
        }
    }

    private var defaultBrowser: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Make Blink your default browser", "Links you open from Mail, Messages, Slack, and other apps will come to Blink first. macOS will ask you to confirm. Links you click inside a browser stay in that browser.")
            GroupBox {
                DefaultBrowserStatusView(system: model.system)
                    .padding(8)
            }
            Text("You can skip this and try Blink first with Open Link… in the menu bar. Links you open before finishing here wait until you're done.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { model.system.refresh() }
    }

    private var login: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Open Blink at login", "Blink needs to be running to route links quickly. It lives in the menu bar and stays out of the way.")
            GroupBox {
                Toggle("Open Blink at login", isOn: Binding(
                    get: { model.system.launchesAtLogin || model.system.loginNeedsApproval },
                    set: { model.system.setLaunchAtLogin($0) }
                ))
                .accessibilityLabel("Open Blink at login")
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.system.loginNeedsApproval {
                Button("Open Login Items Settings") { model.system.openLoginItemsSettings() }
            }
            if let error = model.system.loginError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var done: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("You're all set")
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Open a test link to see the picker, or find Blink in the menu bar to add rules and change settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if waitingCount > 0 {
                waitingNote
            }
        }
        .padding(.top, 40)
    }

    private var waitingNote: some View {
        Label(
            waitingCount == 1 ? "1 link is waiting and will open when you finish." : "\(waitingCount) links are waiting and will open when you finish.",
            systemImage: "link"
        )
        .font(.callout)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
