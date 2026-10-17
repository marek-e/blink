import BlinkCore
import SwiftUI

struct RulesSettingsView: View {
    let model: AppModel

    @State private var selection: UUID?
    @State private var editing: RuleDraft?
    @State private var testText = ""

    private var rules: [Rule] { model.configuration.rules }
    private var isReadOnly: Bool { model.preferences.isReadOnly }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links that match a rule open without asking. The first matching rule wins, so put specific rules above broad ones.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ruleList
                .frame(height: 240)

            HStack(spacing: 8) {
                ControlGroup {
                    Button {
                        editing = RuleDraft(model: model)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Rule")
                    .help("Add a rule")
                    Button {
                        if let selection { model.preferences.update { $0.deleteRule(selection) } }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedRule == nil)
                    .accessibilityLabel("Delete Rule")
                    .help("Delete the selected rule")
                }
                .frame(width: 64)
                .disabled(isReadOnly)

                Button("Edit…") { if let rule = selectedRule { editing = RuleDraft(rule: rule) } }
                    .disabled(selectedRule == nil || isReadOnly)
                ControlGroup {
                    Button { move(by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(selectedIndex == nil || selectedIndex == 0)
                        .accessibilityLabel("Move Rule Up")
                    Button { move(by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(selectedIndex == nil || selectedIndex == rules.count - 1)
                        .accessibilityLabel("Move Rule Down")
                }
                .frame(width: 64)
                .disabled(isReadOnly)
                Spacer()
            }

            Divider()
            RuleTester(model: model, text: $testText)
        }
        .padding(20)
        .frame(width: 560)
        .sheet(item: $editing) { draft in
            RuleEditorView(model: model, draft: draft) { editing = nil }
        }
    }

    private var selectedIndex: Int? { rules.firstIndex { $0.id == selection } }
    private var selectedRule: Rule? { selectedIndex.map { rules[$0] } }

    private func move(by offset: Int) {
        guard let selection else { return }
        model.preferences.update { $0.moveRule(selection, by: offset) }
    }

    private var ruleList: some View {
        List(selection: $selection) {
            ForEach(rules) { rule in
                RuleRow(model: model, rule: rule, shadowedBy: RuleEvaluator.shadowingRule(for: rule, in: rules))
                    .tag(rule.id)
                    .contextMenu {
                        Button("Edit…") { editing = RuleDraft(rule: rule) }
                        Button(rule.isEnabled ? "Disable" : "Enable") { toggle(rule) }
                        Divider()
                        Button("Delete", role: .destructive) { model.preferences.update { $0.deleteRule(rule.id) } }
                    }
                    .disabled(isReadOnly)
            }
            .onMove { source, destination in
                model.preferences.update { $0.rules.move(fromOffsets: source, toOffset: destination) }
            }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: UUID.self) { _ in
        } primaryAction: { ids in
            if !isReadOnly, let id = ids.first, let rule = rules.first(where: { $0.id == id }) {
                editing = RuleDraft(rule: rule)
            }
        }
        .onDeleteCommand {
            if !isReadOnly, let selection { model.preferences.update { $0.deleteRule(selection) } }
        }
        .overlay {
            if rules.isEmpty {
                VStack(spacing: 6) {
                    Text("No Rules").font(.headline)
                    Text("Every link shows the picker. Add a rule to send a domain straight to one browser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }
        }
    }

    private func toggle(_ rule: Rule) {
        var updated = rule
        updated.isEnabled.toggle()
        model.preferences.update { $0.upsertRule(updated) }
    }
}

private struct RuleRow: View {
    let model: AppModel
    let rule: Rule
    let shadowedBy: Rule?

    private var destinationName: String { model.catalog.name(for: rule.destinationBundleID) }
    private var destinationInstalled: Bool { model.catalog.availableIDs.contains(rule.destinationBundleID) }

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: Binding(
                get: { rule.isEnabled },
                set: { enabled in
                    var updated = rule
                    updated.isEnabled = enabled
                    model.preferences.update { $0.upsertRule(updated) }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Enable rule for \(rule.domain)")

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.domain)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                Text(scopeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let shadowedBy {
                    Label("Never used: the rule for \(shadowedBy.domain) above matches first.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if !destinationInstalled {
                    Label("\(destinationName) isn't installed. Matching links will ask you to choose.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Image(nsImage: model.catalog.icon(for: rule.destinationBundleID))
                .resizable()
                .frame(width: 20, height: 20)
                .opacity(destinationInstalled ? 1 : 0.4)
                .accessibilityHidden(true)
            Text(destinationName)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var scopeText: String {
        rule.includeSubdomains && HostNormalizer.supportsSubdomains(rule.domain)
            ? "This domain and its subdomains"
            : "This domain only"
    }

    private var accessibilityText: String {
        var text = "\(rule.domain), \(scopeText), opens in \(destinationName)"
        if !rule.isEnabled { text += ", disabled" }
        if shadowedBy != nil { text += ", never used because an earlier rule matches first" }
        if !destinationInstalled { text += ", browser not installed" }
        return text
    }
}

/// Shows what Blink would do with a link, without opening it.
private struct RuleTester: View {
    let model: AppModel
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Test a link", text: $text, prompt: Text("https://example.com/page"))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Test a link")
            Text(result)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Test result: \(result)")
        }
    }

    private var result: String {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Enter a link to see which rule applies."
        }
        switch LinkValidator.validate(text: text) {
        case let .failure(rejection):
            return rejection.message
        case let .success(link):
            switch RuleEvaluator.evaluate(host: link.host, rules: model.configuration.rules) {
            case .noMatch:
                return "No rule matches \(link.host). Blink will ask which browser to use."
            case let .matched(ruleID, bundleID):
                let rule = model.configuration.rules.first { $0.id == ruleID }
                let name = model.catalog.name(for: bundleID)
                let installed = model.catalog.availableIDs.contains(bundleID)
                return "Opens in \(name) using the rule for \(rule?.domain ?? link.host)."
                    + (installed ? "" : " \(name) isn't installed, so Blink will ask instead.")
            }
        }
    }
}
