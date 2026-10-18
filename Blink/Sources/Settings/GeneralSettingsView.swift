import AppKit
import BlinkCore
import SwiftUI

struct GeneralSettingsView: View {
    let model: AppModel
    let actions: SettingsWindowController.Actions

    @State private var confirmsReset = false

    private var system: SystemIntegration { model.system }

    var body: some View {
        Form {
            if let problem = model.preferences.loadProblem {
                Section {
                    ConfigurationProblemView(model: model, problem: problem, confirmsReset: $confirmsReset)
                }
            }

            Section {
                DefaultBrowserStatusView(system: system)
            } header: {
                Text("Default Browser")
            } footer: {
                Text("When Blink is your default browser, links you open in other apps come to Blink first. Links you click inside a browser stay in that browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Open Blink at login", isOn: Binding(
                    get: { system.launchesAtLogin || system.loginNeedsApproval },
                    set: { system.setLaunchAtLogin($0) }
                ))
                .accessibilityLabel("Open Blink at login")
                if system.loginNeedsApproval {
                    HStack {
                        Text("Allow Blink in Login Items to finish turning this on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items") { system.openLoginItemsSettings() }
                            .controlSize(.small)
                    }
                }
                if let error = system.loginError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Toggle("Show Blink in the menu bar", isOn: Binding(
                    get: { model.configuration.showsMenuBarIcon },
                    set: { shows in model.preferences.update { $0.showsMenuBarIcon = shows } }
                ))
                .accessibilityLabel("Show Blink in the menu bar")
                .disabled(model.preferences.isReadOnly)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("When the icon is hidden, open Blink again from Applications or Spotlight to see these settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Links") {
                LabeledContent("Try Blink without changing your default browser") {
                    Button("Open Link…", action: actions.openLink)
                }
                LabeledContent("Review browsers, default browser, and login settings") {
                    Button("Show Welcome…", action: actions.showWelcome)
                }
            }

            Section {
                LabeledContent("Version", value: Self.versionText)
                LabeledContent("Settings file") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.preferences.fileURL])
                    }
                    .disabled(!FileManager.default.fileExists(atPath: model.preferences.fileURL.path))
                }
                LabeledContent("Start over with default settings") {
                    Button("Reset Settings…") { confirmsReset = true }
                }
                LabeledContent("Stop Blink until you open it again") {
                    Button("Quit Blink", action: actions.quit)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Blink keeps your settings on this Mac. It doesn't keep a history of the links you open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 600)
        .confirmationDialog("Reset Blink's settings?", isPresented: $confirmsReset) {
            Button("Reset Settings", role: .destructive) {
                model.preferences.reset(discovered: model.catalog.browsers)
            }
        } message: {
            Text("Your rules and browser order will be removed. Blink keeps a backup of the current settings file next to the new one.")
        }
        .onAppear { system.refresh() }
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

struct DefaultBrowserStatusView: View {
    let system: SystemIntegration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                statusIcon
                Text(statusText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .accessibilityElement(children: .combine)

            if system.defaultBrowserState != .blink {
                HStack {
                    Button(system.isChangingDefault ? "Waiting for macOS…" : "Set Blink as Default Browser") {
                        Task { await system.makeBlinkDefault() }
                    }
                    .disabled(system.isChangingDefault)
                    Button("Open System Settings") { system.openDefaultBrowserSettings() }
                }
                if system.defaultChangeFailed {
                    Text("The default browser wasn't changed. You can choose Blink in System Settings › Desktop & Dock › Default web browser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch system.defaultBrowserState {
        case .blink:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityHidden(true)
        case .partial:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityHidden(true)
        case .other:
            Image(systemName: "circle.dashed").foregroundStyle(.secondary).accessibilityHidden(true)
        }
    }

    private var statusText: String {
        switch system.defaultBrowserState {
        case .blink:
            "Blink is your default browser for HTTP and HTTPS links."
        case let .partial(http, _):
            http
                ? "Blink opens HTTP links, but HTTPS links go to another app. Set Blink as default again to finish."
                : "Blink opens HTTPS links, but HTTP links go to another app. Set Blink as default again to finish."
        case .other:
            if let name = system.otherHandlerName { "\(name) is your default browser." } else { "Blink isn't your default browser." }
        }
    }
}

private struct ConfigurationProblemView: View {
    let model: AppModel
    let problem: ConfigurationError
    @Binding var confirmsReset: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Saved settings couldn't be loaded", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(explanation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Reset Settings…") { confirmsReset = true }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.preferences.fileURL])
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var explanation: String {
        let reason = switch problem {
        case .unsupportedVersion: "They were saved by a newer version of Blink."
        case .invalid: "The settings file is damaged or was edited by hand."
        }
        return "\(reason) Blink left the file untouched and is using temporary defaults: your browsers are listed in name order and no rules apply. Changes can't be saved until you reset, which keeps a backup of the original."
    }
}
