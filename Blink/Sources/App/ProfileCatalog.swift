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
    private(set) var profiles: [String: [ProfileReference]] = [:]

    @ObservationIgnored private var modificationDates: [String: Date] = [:]

    /// The browser's profiles, or nothing when it has fewer than two or Blink can't read them.
    func profiles(for bundleID: String) -> [ProfileReference] {
        profiles[bundleID] ?? []
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
            let known = modificationDates[bundleID]
            let read = await Task.detached(priority: .userInitiated) {
                Self.read(support, unlessModifiedAt: known)
            }.value
            switch read {
            case .unchanged:
                continue
            case let .read(list, modified):
                modificationDates[bundleID] = modified
                let usable = list.count > 1 ? list : []
                if profiles[bundleID] != usable { profiles[bundleID] = usable }
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
        return profiles(for: bundleID).first { $0 == profile }
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
