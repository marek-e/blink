import Foundation

/// Where a link goes: a browser, and optionally one of its profiles.
public struct Destination: Codable, Hashable, Sendable {
    public var bundleID: String
    /// Nil opens the browser the way it normally opens links.
    public var profile: ProfileReference?

    public init(bundleID: String, profile: ProfileReference? = nil) {
        self.bundleID = bundleID
        self.profile = profile
    }
}

/// A browser profile, or an Arc space.
///
/// Equality and hashing use `id` only, so a renamed profile is still the same profile.
public struct ProfileReference: Codable, Hashable, Sendable {
    /// Survives renames: an Arc space ID, a Chromium profile directory, or a Firefox profile path.
    public var id: String
    /// The last name seen, for display when the profile is gone.
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
