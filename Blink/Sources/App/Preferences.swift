import BlinkCore
import Foundation
import Observation

/// The live configuration. Edits are shown only after they have been saved.
@MainActor
@Observable
final class Preferences {
    struct SaveFailure: Identifiable {
        enum Kind {
            case edit(Configuration)
            case reset(discovered: [DiscoveredBrowser])
        }

        let id = UUID()
        let kind: Kind
    }

    private(set) var configuration: Configuration
    /// Set when the saved file couldn't be loaded. Blink then runs on temporary defaults and never
    /// writes over the original until the user resets.
    private(set) var loadProblem: ConfigurationError?
    var saveFailure: SaveFailure?

    @ObservationIgnored private let store: ConfigurationStore

    init(store: ConfigurationStore) {
        self.store = store
        switch store.load() {
        case .firstRun:
            configuration = Configuration()
        case let .loaded(configuration):
            self.configuration = configuration
        case let .recovery(problem):
            configuration = Configuration(onboardingCompleted: true)
            loadProblem = problem
            Log.configuration.error("Saved settings could not be loaded; using temporary defaults")
        }
    }

    var isReadOnly: Bool { loadProblem != nil }
    var fileURL: URL { store.fileURL }

    /// Applies `change` and saves it. On failure the previous configuration stays in effect.
    @discardableResult
    func update(_ change: (inout Configuration) -> Void) -> Bool {
        var next = configuration
        change(&next)
        guard next != configuration else { return true }
        return commit(next)
    }

    @discardableResult
    func commit(_ next: Configuration) -> Bool {
        guard !isReadOnly else { return false }
        do {
            try store.save(next)
            configuration = next
            saveFailure = nil
            return true
        } catch {
            Log.configuration.error("Saving settings failed")
            saveFailure = SaveFailure(kind: .edit(next))
            return false
        }
    }

    /// Repeats the operation that failed. A failed reset is retried as a reset, so the backup still happens.
    func retry(_ failure: SaveFailure) {
        switch failure.kind {
        case let .edit(configuration): commit(configuration)
        case let .reset(discovered): reset(discovered: discovered)
        }
    }

    /// Adds newly installed browsers. This isn't a user edit, so a failed save keeps the change in memory.
    func mergeDiscovered(_ browsers: [DiscoveredBrowser]) {
        var next = configuration
        guard next.mergeDiscovered(browsers) else { return }
        if !isReadOnly {
            do {
                try store.save(next)
            } catch {
                Log.configuration.error("Saving discovered browsers failed")
            }
        }
        configuration = next
    }

    /// Backs up the current file and starts over with defaults.
    @discardableResult
    func reset(discovered: [DiscoveredBrowser]) -> Bool {
        var fresh = Configuration(onboardingCompleted: true)
        fresh.mergeDiscovered(discovered)
        do {
            try store.reset(to: fresh)
            configuration = fresh
            loadProblem = nil
            saveFailure = nil
            Log.configuration.notice("Settings reset; previous file backed up")
            return true
        } catch {
            Log.configuration.error("Resetting settings failed")
            saveFailure = SaveFailure(kind: .reset(discovered: discovered))
            return false
        }
    }
}
