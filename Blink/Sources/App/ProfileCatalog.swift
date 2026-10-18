import BlinkCore
import Foundation
import Observation

/// Profiles of installed browsers, read from each browser's own profile list.
///
/// Only profile IDs and names are kept. Files are read off the main thread and again only when
/// they change; anything unreadable means "no profiles" for that browser.
@MainActor
@Observable
final class ProfileCatalog {
    /// Every profile found, by bundle ID.
    private(set) var profiles: [String: [ProfileReference]] = [:]

    @ObservationIgnored private var modificationDates: [String: Date] = [:]

    /// The browser's profiles to choose from: none when it has fewer than two, since there's
    /// nothing to choose, or when Blink can't read them.
    func choices(for bundleID: String) -> [ProfileReference] {
        let all = profiles[bundleID] ?? []
        return all.count > 1 ? all : []
    }

    /// Whether `profile` is among the browser's profiles; nil when Blink has no list to check against.
    func contains(_ profile: ProfileReference, for bundleID: String) -> Bool? {
        profiles[bundleID].map { $0.contains(profile) }
    }

    /// Starts reading the lists of `bundleIDs` that changed, without waiting for the result.
    func refreshInBackground(_ bundleIDs: some Sequence<String>) {
        let bundleIDs = Array(bundleIDs)
        Task { await refresh(bundleIDs) }
    }

    /// Reads the lists of `bundleIDs` that changed since the last read.
    func refresh(_ bundleIDs: some Sequence<String>) async {
        for bundleID in bundleIDs {
            guard let support = ProfileSupport.forBundleID(bundleID) else { continue }
            // Firefox profiles count only once they have a prefs.js, which appears without
            // profiles.ini changing, so that small file is always read again.
            let known = support.family == .firefox ? nil : modificationDates[bundleID]
            let read = await Task.detached(priority: .userInitiated) {
                Self.read(support, unlessModifiedAt: known)
            }.value
            switch read {
            case .unchanged:
                continue
            case let .read(list, modified):
                modificationDates[bundleID] = modified
                // Compare names too: `ProfileReference` equality ignores them.
                let previous = profiles[bundleID]
                if previous?.map(\.id) != list.map(\.id) || previous?.map(\.name) != list.map(\.name) {
                    profiles[bundleID] = list
                }
            case .unavailable:
                modificationDates[bundleID] = nil
                if profiles[bundleID] != nil { profiles[bundleID] = nil }
                Log.profiles.notice("No profile list for a browser that supports profiles")
            }
        }
    }

    /// The current version of `profile`, after re-reading the browser's list. Nil when it's gone.
    func current(_ profile: ProfileReference, for bundleID: String) async -> ProfileReference? {
        await refresh([bundleID])
        return profiles[bundleID]?.first { $0 == profile }
    }

    private enum ReadResult: Sendable {
        case unchanged
        case read([ProfileReference], modified: Date)
        case unavailable
    }

    private nonisolated static func read(_ support: ProfileSupport, unlessModifiedAt known: Date?) -> ReadResult {
        let url = URL.applicationSupportDirectory.appending(path: support.listPath, directoryHint: .notDirectory)
        guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
            return .unavailable
        }
        if modified == known { return .unchanged }
        guard let data = try? Data(contentsOf: url) else { return .unavailable }

        let list: [ProfileReference]
        switch support.family {
        case .arc:
            list = ProfileListParser.arcSpaces(sidebar: data)
        case .dia, .chromium:
            list = ProfileListParser.chromium(localState: data)
        case .firefox:
            let folder = url.deletingLastPathComponent()
            list = ProfileListParser.firefox(profilesINI: String(decoding: data, as: UTF8.self))
                // Profiles that were never opened (no prefs.js yet) are leftovers, not choices.
                .filter { profile in
                    let directory = profile.isRelative ? folder.appending(path: profile.path) : URL(filePath: profile.path)
                    return FileManager.default.fileExists(atPath: directory.appending(path: "prefs.js").path)
                }
                .map(\.reference)
        }
        return .read(list, modified: modified)
    }
}
