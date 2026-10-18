import BlinkCore
import SwiftUI

struct BrowsersSettingsView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browsers appear in the picker in this order. Hidden browsers are left out of the picker, but rules can still open links in them.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            BrowserPreferencesList(model: model)
                .frame(height: 300)

            HStack {
                Button {
                    model.refreshBrowsers()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Spacer()
                Text("Missing a browser? Make sure it's in your Applications folder, then refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}

/// The ordered browser list with visibility toggles and keyboard-accessible reordering.
/// Shared by Settings and the welcome window.
struct BrowserPreferencesList: View {
    let model: AppModel
    @State private var selection: String?

    private var preferences: [BrowserPreference] { model.configuration.browsers }

    var body: some View {
        List(selection: $selection) {
            ForEach(Array(preferences.enumerated()), id: \.element.bundleID) { index, preference in
                row(preference, index: index)
                    .tag(preference.bundleID)
            }
            .onMove { source, destination in
                model.preferences.update { $0.browsers.move(fromOffsets: source, toOffset: destination) }
            }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        // Edits can't be saved while the settings file is in recovery. Refresh stays available
        // because it only updates the temporary in-memory list.
        .disabled(model.preferences.isReadOnly)
        .onAppear { selection = selection ?? preferences.first?.bundleID }
    }

    private func row(_ preference: BrowserPreference, index: Int) -> some View {
        let available = model.catalog.availableIDs
        let isInstalled = available.contains(preference.bundleID)
        let name = model.catalog.name(for: preference.bundleID)
        let canToggle = !preference.isVisible || model.configuration.canHide(preference.bundleID, available: available)

        return HStack(spacing: 10) {
            Image(nsImage: model.catalog.icon(for: preference.bundleID))
                .resizable()
                .frame(width: 24, height: 24)
                .opacity(isInstalled ? 1 : 0.4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).lineLimit(1)
                if !isInstalled {
                    Text("Not installed").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Show in picker", isOn: Binding(
                get: { preference.isVisible },
                set: { visible in model.preferences.update { $0.setVisibility(visible, for: preference.bundleID) } }
            ))
            .toggleStyle(.checkbox)
            .disabled(!canToggle)
            .help(canToggle ? "Show \(name) in the picker" : "At least one available browser must stay in the picker.")
            .accessibilityLabel("Show \(name) in picker")

            ControlGroup {
                Button {
                    model.preferences.update { $0.moveBrowser(preference.bundleID, by: -1) }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                .accessibilityLabel("Move \(name) up")
                Button {
                    model.preferences.update { $0.moveBrowser(preference.bundleID, by: 1) }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == preferences.count - 1)
                .accessibilityLabel("Move \(name) down")
            }
            .controlSize(.small)
            .frame(width: 56)

            if !isInstalled {
                Button {
                    model.preferences.update { $0.removeBrowser(preference.bundleID) }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Forget \(name)")
                .accessibilityLabel("Forget \(name)")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isInstalled ? name : "\(name), not installed")
    }
}
