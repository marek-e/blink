import BlinkCore
import SwiftUI

struct PickerContainer: View {
    let model: AppModel
    let session: PickerSession
    let choose: (Int) -> Void
    let showSettings: (SettingsTab) -> Void

    var body: some View {
        if let active = model.coordinator.active {
            PickerView(model: model, session: session, active: active, choose: choose, showSettings: showSettings)
                .id(active.request.id)
        } else {
            Color.clear.frame(width: PickerView.width, height: 1)
        }
    }
}

/// The picker's content. Keyboard input (arrows, Return, 1–9) is handled by `PickerPanel`.
struct PickerView: View {
    static let width: CGFloat = 360
    static let cornerRadius: CGFloat = PickerGlass.isAvailable ? 22 : 14
    /// Room kept for the header, a banner and the footer when limiting the browser list's height.
    static let reservedHeight: CGFloat = 300

    let model: AppModel
    @Bindable var session: PickerSession
    let active: ActiveRequest
    let choose: (Int) -> Void
    let showSettings: (SettingsTab) -> Void

    @State private var copied = false
    @State private var hovered: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    private var link: ValidatedLink { active.request.link }
    private var choices: [DiscoveredBrowser] { model.pickerChoices }
    private var waitingCount: Int { model.coordinator.queued.count }
    /// While a link is being sent, the highlight follows the browser it's going to.
    private var selection: Int {
        if case let .dispatching(bundleID) = active.phase,
           let index = choices.firstIndex(where: { $0.bundleID == bundleID }) {
            return index
        }
        return min(session.selection, max(choices.count - 1, 0))
    }
    private var canCreateRule: Bool { model.canCreateRule(for: active) }

    private var isDispatching: Bool {
        if case .dispatching = active.phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if case let .failed(failure) = active.phase {
                failureBanner(failure)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            } else if case let .dispatching(bundleID) = active.phase, active.isSlow {
                slowBanner(name: model.catalog.name(for: bundleID))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            Divider()

            if choices.isEmpty {
                emptyState
            } else {
                browserList
            }

            footer
        }
        .frame(width: Self.width)
        .modifier(PanelBackground(shape: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)))
        .onExitCommand { model.cancel(active.request.id) }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: link.kind == .file ? "doc" : "link")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(LinkPreview.title(of: link))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(LinkPreview.title(of: link))
                    Text(LinkPreview.summary(of: link))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 8)
                if waitingCount > 0 {
                    Text(waitingCount == 1 ? "1 more link" : "\(waitingCount) more links")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .accessibilityLabel(waitingCount == 1 ? "1 more link waiting" : "\(waitingCount) more links waiting")
                }
            }

            DisclosureGroup(isExpanded: $session.showsFullLink) {
                ScrollView {
                    Text(link.url.absoluteString)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 72)
                .padding(.top, 2)
            } label: {
                Text("Full link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Failure

    private func failureBanner(_ failure: RequestFailure) -> some View {
        let name = model.catalog.name(for: failure.bundleID)
        let title: String
        let detail: String
        switch failure {
        case .destinationUnavailable where active.matchedRuleID != nil:
            title = "\(name) isn't available"
            detail = "A rule sends this link to \(name), but it isn't installed or can't open this link. Choose a browser for this link, or update the rule."
        case .destinationUnavailable:
            title = "\(name) isn't available"
            detail = "It may have been moved or removed. Choose another browser."
        case .launchFailed:
            title = "\(name) couldn't open this link"
            detail = "Try again, or choose another browser."
        }

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    if case .launchFailed = failure {
                        Button("Try Again") { model.retry(active.request.id) }
                    }
                    if case .destinationUnavailable = failure, active.matchedRuleID != nil {
                        Button("Edit Rules") { showSettings(.rules) }
                    }
                }
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .onAppear { Announcer.announce("\(title). \(detail)") }
    }

    private func slowBanner(name: String) -> some View {
        let title = "Still waiting for \(name)"
        let detail = "macOS hasn't confirmed that \(name) received the link. It may still be starting, or showing a message in another window. Keep waiting, or cancel."
        return HStack(alignment: .top, spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { Announcer.announce("\(title). \(detail)") }
    }

    // MARK: Browsers

    /// Scrolls only when every row wouldn't fit on the screen.
    @ViewBuilder
    private var browserList: some View {
        let rowsHeight = CGFloat(choices.count) * BrowserRow.height + 12
        let maxHeight = max(session.maxListHeight, 3 * BrowserRow.height)
        if rowsHeight > maxHeight {
            ScrollViewReader { proxy in
                ScrollView {
                    browserRows
                }
                .frame(height: maxHeight)
                .onChange(of: selection) {
                    guard choices.indices.contains(selection) else { return }
                    proxy.scrollTo(choices[selection].bundleID)
                }
            }
        } else {
            browserRows
        }
    }

    private var browserRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(choices.enumerated()), id: \.element.bundleID) { index, browser in
                BrowserRow(
                    model: model,
                    browser: browser,
                    shortcut: index < 9 ? index + 1 : nil,
                    isSelected: index == selection,
                    isHovered: hovered == browser.bundleID,
                    isActive: controlActiveState == .key,
                    isOpening: active.phase == .dispatching(bundleID: browser.bundleID)
                )
                .contentShape(Rectangle())
                .onTapGesture { choose(index) }
                .onHover { inside in
                    if inside {
                        hovered = browser.bundleID
                    } else if hovered == browser.bundleID {
                        hovered = nil
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(browser.name)
                .accessibilityHint(index < 9 ? "Press \(index + 1) to open" : "")
                .accessibilityAddTraits(index == selection ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { choose(index) }
                .id(browser.bundleID)
            }
        }
        .padding(6)
        .disabled(isDispatching)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browsers")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "safari")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No browser is available for this link")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Install a browser, or show a hidden one in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Refresh") { model.refreshBrowsers() }
                Button("Settings") { showSettings(.browsers) }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .onAppear { Announcer.announce("No browser is available for this link") }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if canCreateRule && !choices.isEmpty {
                Divider()
                Toggle(isOn: $session.alwaysForHost) {
                    Text("Always open \(link.host) in the chosen browser")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .toggleStyle(.checkbox)
                .font(.callout)
                .help("Adds a rule for this exact domain. You can change it in Settings.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
            actionBar
        }
        .animation(reduceMotion ? nil : .default, value: copied)
    }

    /// Command-palette style: each action names the key that runs it, and the primary action
    /// names the browser Return opens.
    @ViewBuilder
    private var actionBar: some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassActionBar
        } else {
            plainActionBar
        }
        #else
        plainActionBar
        #endif
    }

    private var plainActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 2) {
                copyButton(emphasis: .secondary).fixedSize()
                Spacer(minLength: 8)
                cancelButton(emphasis: .secondary).fixedSize()
                openAction(emphasis: .primary)
            }
            .buttonStyle(ActionBarButtonStyle())
            .padding(.horizontal, 6)
            .frame(height: 38)
            // An explicit shape: without one, the style fills the container shape, which draws
            // the bar as an inset rounded card.
            .background(.quinary, in: Rectangle())
        }
    }

    #if compiler(>=6.2)
    @available(macOS 26, *)
    private var glassActionBar: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                copyButton(emphasis: .primary).fixedSize()
                    .buttonStyle(.glass)
                    .modifier(GlassHover())
                Spacer(minLength: 0)
                cancelButton(emphasis: .primary).fixedSize()
                    .buttonStyle(.glass)
                    .modifier(GlassHover())
                openAction(emphasis: .onAccent)
                    .buttonStyle(.glassProminent)
                    .modifier(GlassHover(isProminent: true))
            }
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
    #endif

    private func copyButton(emphasis: ActionLabel.Emphasis) -> some View {
        Button {
            AppModel.copyToPasteboard(link.url)
            copied = true
            Announcer.announce("Link copied")
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            ActionLabel(title: copied ? "Copied" : "Copy", key: "⌘C", emphasis: emphasis)
        }
        .accessibilityLabel("Copy Link")
    }

    private func cancelButton(emphasis: ActionLabel.Emphasis) -> some View {
        Button(role: .cancel) {
            model.cancel(active.request.id)
        } label: {
            ActionLabel(title: "Cancel", key: "esc", emphasis: emphasis)
        }
        .disabled(isDispatching && !active.isSlow)
    }

    @ViewBuilder
    private func openAction(emphasis: ActionLabel.Emphasis) -> some View {
        if isDispatching {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Opening…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Opening")
        } else if choices.indices.contains(selection) {
            // Just "Open", so the bar keeps its width as the selection moves.
            Button {
                choose(selection)
            } label: {
                ActionLabel(title: "Open", key: "↩", emphasis: emphasis)
            }
            .accessibilityLabel("Open in \(choices[selection].name)")
        }
    }
}

/// Liquid Glass on macOS 26 and later, when built with its SDK; materials before that.
enum PickerGlass {
    static var isAvailable: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26, *) { return true }
        #endif
        return false
    }
}

private struct PanelBackground<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            return AnyView(content.clipShape(shape).glassEffect(.regular, in: shape))
        }
        #endif
        return AnyView(content
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
            .clipShape(shape))
    }
}

/// A keyboard key, drawn like a keycap.
private struct KeyCap: View {
    enum Tint { case neutral, accent, onAccent }

    let key: String
    var tint = Tint.neutral

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(key)
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(foreground)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, key.count > 1 ? 4 : 0)
            .background(background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityHidden(true)
    }

    private var foreground: AnyShapeStyle {
        switch tint {
        case .neutral: AnyShapeStyle(.secondary)
        // Accent text on a dark accent-tinted row is too faint, so dark mode inverts it.
        case .accent: colorScheme == .dark ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.accentColor)
        case .onAccent: AnyShapeStyle(Color.white.opacity(0.9))
        }
    }

    private var background: AnyShapeStyle {
        switch tint {
        case .neutral: AnyShapeStyle(.quaternary)
        case .accent: AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.6 : 0.15))
        case .onAccent: AnyShapeStyle(Color.white.opacity(0.22))
        }
    }
}

private struct ActionLabel: View {
    enum Emphasis { case secondary, primary, onAccent }

    let title: String
    let key: String
    let emphasis: Emphasis

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.callout.weight(emphasis == .secondary ? .regular : .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .truncationMode(.tail)
            KeyCap(key: key, tint: emphasis == .onAccent ? .onAccent : .neutral)
        }
    }

    private var foreground: AnyShapeStyle {
        switch emphasis {
        case .secondary: AnyShapeStyle(.secondary)
        case .primary: AnyShapeStyle(.primary)
        case .onAccent: AnyShapeStyle(Color.white)
        }
    }
}

private struct ActionBarButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        ActionBarButton(configuration: configuration)
    }

    private struct ActionBarButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(fill)
                }
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { isHovered = $0 }
        }

        private var fill: AnyShapeStyle {
            if configuration.isPressed { return AnyShapeStyle(.tertiary) }
            return isHovered && isEnabled ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)
        }
    }
}

/// Glass buttons don't react to the pointer on macOS, so this marks hover itself: a lighter tint
/// for the prominent button, a shade over the others. `.brightness` and overlays don't reach
/// prominent glass, which the system draws separately.
@available(macOS 26, *)
private struct GlassHover: ViewModifier {
    var isProminent = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var showsHover: Bool { isHovered && isEnabled }

    func body(content: Content) -> some View {
        Group {
            if isProminent {
                content.tint(showsHover ? Color.accentColor.mix(with: .white, by: 0.18) : .accentColor)
            } else {
                content.overlay {
                    Capsule()
                        .fill(.tertiary)
                        .opacity(showsHover ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: showsHover)
        .onHover { isHovered = $0 }
    }
}

private struct BrowserRow: View {
    static let height: CGFloat = 36

    let model: AppModel
    let browser: DiscoveredBrowser
    let shortcut: Int?
    let isSelected: Bool
    let isHovered: Bool
    let isActive: Bool
    let isOpening: Bool

    private var isHighlighted: Bool { isSelected && isActive }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: model.catalog.icon(for: browser.bundleID))
                .resizable()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(browser.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if isOpening {
                Text("Opening…").font(.caption).foregroundStyle(.secondary)
            } else if let shortcut {
                KeyCap(key: "\(shortcut)", tint: isHighlighted ? .accent : .neutral)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Self.height)
        .background {
            let shape = RoundedRectangle(cornerRadius: PickerGlass.isAvailable ? 12 : 8, style: .continuous)
            if isHighlighted {
                shape.fill(Color.accentColor.opacity(0.2))
            } else if isSelected {
                shape.fill(.quaternary)
            } else if isHovered {
                shape.fill(.quaternary.opacity(0.8))
            }
        }
    }
}
