import BlinkCore
import SwiftUI

struct RuleDraft: Identifiable {
    let id: UUID
    let isNew: Bool
    let originalDestination: String?
    var domainText: String
    var includeSubdomains: Bool
    var destination: String
    var isEnabled: Bool

    @MainActor
    init(model: AppModel) {
        id = UUID()
        isNew = true
        originalDestination = nil
        domainText = ""
        includeSubdomains = false
        destination = model.configuration.pickerChoices(from: model.catalog.browsers).first?.bundleID
            ?? model.catalog.browsers.first?.bundleID ?? ""
        isEnabled = true
    }

    init(rule: Rule) {
        id = rule.id
        isNew = false
        originalDestination = rule.destinationBundleID
        domainText = rule.domain
        includeSubdomains = rule.includeSubdomains
        destination = rule.destinationBundleID
        isEnabled = rule.isEnabled
    }
}

struct RuleEditorView: View {
    let model: AppModel
    @State var draft: RuleDraft
    let dismiss: () -> Void

    @FocusState private var domainFocused: Bool
    @State private var saveFailed = false

    init(model: AppModel, draft: RuleDraft, dismiss: @escaping () -> Void) {
        self.model = model
        _draft = State(initialValue: draft)
        self.dismiss = dismiss
    }

    private var normalized: Result<String, RuleDomainError> { HostNormalizer.normalizeRuleDomain(draft.domainText) }
    private var domain: String? { try? normalized.get() }
    private var supportsSubdomains: Bool { domain.map(HostNormalizer.supportsSubdomains) ?? true }

    /// Installed browsers in picker order, including hidden ones, plus the rule's current
    /// destination if it's no longer installed.
    private var destinations: [(id: String, name: String, installed: Bool)] {
        let available = model.catalog.availableIDs
        var ids = model.configuration.browsers.map(\.bundleID).filter(available.contains)
        ids += model.catalog.browsers.map(\.bundleID).filter { !ids.contains($0) }
        var result = ids.map { (id: $0, name: model.catalog.name(for: $0), installed: true) }
        if let original = draft.originalDestination, !available.contains(original) {
            result.append((id: original, name: model.catalog.name(for: original), installed: false))
        }
        return result
    }

    private var destinationIsValid: Bool {
        model.catalog.availableIDs.contains(draft.destination) || draft.destination == draft.originalDestination
    }

    private var candidate: Rule? {
        guard let domain, !draft.destination.isEmpty else { return nil }
        return Rule(
            id: draft.id,
            domain: domain,
            includeSubdomains: draft.includeSubdomains && HostNormalizer.supportsSubdomains(domain),
            destinationBundleID: draft.destination,
            isEnabled: draft.isEnabled
        )
    }

    private var rulesWithCandidate: [Rule] {
        guard let candidate else { return model.configuration.rules }
        var configuration = model.configuration
        configuration.upsertRule(candidate)
        return configuration.rules
    }

    private var shadowingRule: Rule? {
        candidate.flatMap { RuleEvaluator.shadowingRule(for: $0, in: rulesWithCandidate) }
    }

    private var shadowedCount: Int {
        guard let candidate, candidate.isEnabled else { return 0 }
        let rules = rulesWithCandidate
        guard let index = rules.firstIndex(where: { $0.id == candidate.id }) else { return 0 }
        return rules[(index + 1)...].filter { $0.isEnabled && $0.isShadowed(by: candidate) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.isNew ? "New Rule" : "Edit Rule")
                .font(.headline)

            Form {
                TextField("Domain", text: $draft.domainText, prompt: Text("example.com"))
                    .focused($domainFocused)
                    .onSubmit(save)
                domainFeedback
                Toggle("Include subdomains", isOn: $draft.includeSubdomains)
                    .disabled(!supportsSubdomains)
                    .help(supportsSubdomains
                        ? "Also match addresses such as docs.\(domain ?? "example.com")"
                        : "Subdomains don't apply to IP addresses or single-word hosts.")
                Picker("Open in", selection: $draft.destination) {
                    ForEach(destinations, id: \.id) { destination in
                        Text(destination.installed ? destination.name : "\(destination.name) (not installed)")
                            .tag(destination.id)
                    }
                }
                Toggle("Enabled", isOn: $draft.isEnabled)
            }
            .formStyle(.columns)

            warnings

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: dismiss)
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "Add Rule" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(candidate == nil || !destinationIsValid)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { domainFocused = true }
    }

    @ViewBuilder
    private var domainFeedback: some View {
        if draft.domainText.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("Enter a domain only, such as example.com. Matching is exact unless you include subdomains.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            switch normalized {
            case let .success(domain):
                Text(matchDescription(domain))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case let .failure(error):
                Label(error.message, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func matchDescription(_ domain: String) -> String {
        draft.includeSubdomains && HostNormalizer.supportsSubdomains(domain)
            ? "Matches \(domain) and addresses ending in .\(domain)"
            : "Matches \(domain) exactly"
    }

    @ViewBuilder
    private var warnings: some View {
        if let shadowingRule {
            Label("The rule for \(shadowingRule.domain) is earlier in the list and matches these links first, so this rule won't be used. Move it above that rule after saving.", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        if shadowedCount > 0 {
            Label(shadowedCount == 1
                ? "This rule matches first for 1 later rule, which won't be used."
                : "This rule matches first for \(shadowedCount) later rules, which won't be used.",
                systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        if saveFailed {
            Label("Blink couldn't save this rule. Your previous rules are still in effect.", systemImage: "xmark.octagon")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !destinationIsValid || destinations.isEmpty {
            Label("Choose an installed browser.", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func save() {
        guard let candidate, destinationIsValid else { return }
        if model.preferences.update({ $0.upsertRule(candidate) }) {
            dismiss()
        } else {
            // Report here; the settings window can't show its own alert over this sheet.
            model.preferences.saveFailure = nil
            saveFailed = true
        }
    }
}
