import Foundation

/// Drops a link that arrives again within a moment of itself.
///
/// Some apps hand macOS the same link twice for one click (for example on Command-click), which
/// would show the picker a second time after the first choice. Nobody repeats a link on purpose
/// within a second, so such a copy is treated as the same delivery. Later repeats stay separate
/// requests (B11). Only the most recent link is remembered, in memory.
public struct DuplicateDeliveryFilter: Sendable {
    public static let window: Duration = .seconds(1)

    private var last: (url: URL, time: ContinuousClock.Instant)?

    public init() {}

    /// Whether `url` repeats the previous delivery within `window`. Records it either way, so a
    /// steady stream of copies keeps being dropped.
    public mutating func isDuplicate(_ url: URL, at time: ContinuousClock.Instant = .now) -> Bool {
        defer { last = (url, time) }
        guard let last, last.url.absoluteString == url.absoluteString else { return false }
        return time - last.time < Self.window
    }
}
