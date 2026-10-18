import Foundation

/// One row in the picker: a browser, or one of its profiles shown under it.
public struct PickerRow: Equatable, Identifiable, Sendable {
    public let destination: Destination
    /// How many profiles a browser row can show; zero on profile rows.
    public let profileCount: Int
    public let isExpanded: Bool
    /// The number key that opens this row. Only browser rows have one.
    public let shortcut: Int?

    public var id: String {
        destination.profile.map { "\(destination.bundleID)\u{1F}\($0.id)" } ?? destination.bundleID
    }

    public var isProfile: Bool { destination.profile != nil }
}

/// The picker's rows and selection. Browsers come in the user's order; an expanded browser is
/// followed by its profiles. Number keys address browser rows only, so a browser keeps its
/// number when another one is expanded.
public struct PickerOutline: Equatable, Sendable {
    public private(set) var rows: [PickerRow] = []
    public private(set) var expanded: Set<String>
    public private(set) var selection: Int

    private let browsers: [String]
    private let profiles: [String: [ProfileReference]]

    /// - Parameters:
    ///   - browsers: bundle IDs in picker order.
    ///   - profiles: the profiles each browser offers; browsers without an entry have no ›.
    public init(browsers: [String], profiles: [String: [ProfileReference]], expanded: Set<String> = [], selection: Int = 0) {
        let offered = profiles.filter { !$0.value.isEmpty }
        self.browsers = browsers
        self.profiles = offered
        self.expanded = expanded.filter { offered[$0] != nil }
        self.selection = 0
        rows = makeRows()
        self.selection = clamped(selection)
    }

    public var selectedRow: PickerRow? {
        rows.indices.contains(selection) ? rows[selection] : nil
    }

    /// The row a number key opens, if any.
    public func index(forShortcut number: Int) -> Int? {
        rows.firstIndex { $0.shortcut == number }
    }

    public mutating func select(_ index: Int) {
        selection = clamped(index)
    }

    /// Up and down arrows, wrapping around.
    public mutating func move(by offset: Int) {
        guard !rows.isEmpty else { return }
        selection = ((selection + offset) % rows.count + rows.count) % rows.count
    }

    /// → on a browser shows its profiles and selects the first; on an expanded browser it moves into them.
    public mutating func expandSelection() {
        guard let row = selectedRow, !row.isProfile, row.profileCount > 0 else { return }
        if !row.isExpanded { setExpanded(true, for: row.destination.bundleID) }
        selection += 1
    }

    /// ← on a profile goes back to its browser and hides the profiles; on an expanded browser it hides them.
    public mutating func collapseSelection() {
        guard let row = selectedRow, row.isProfile || row.isExpanded else { return }
        setExpanded(false, for: row.destination.bundleID)
    }

    /// The › button. The selection stays on the same row, or moves to the browser when its
    /// profile row disappears.
    public mutating func toggle(_ bundleID: String) {
        guard profiles[bundleID] != nil else { return }
        setExpanded(!expanded.contains(bundleID), for: bundleID)
    }

    private mutating func setExpanded(_ isExpanded: Bool, for bundleID: String) {
        let selected = selectedRow
        if isExpanded { expanded.insert(bundleID) } else { expanded.remove(bundleID) }
        rows = makeRows()
        guard let selected else { return }
        selection = rows.firstIndex { $0.id == selected.id }
            ?? rows.firstIndex { $0.id == selected.destination.bundleID }
            ?? clamped(selection)
    }

    private func makeRows() -> [PickerRow] {
        var rows: [PickerRow] = []
        for (index, bundleID) in browsers.enumerated() {
            let offered = profiles[bundleID] ?? []
            let isExpanded = expanded.contains(bundleID)
            rows.append(PickerRow(
                destination: Destination(bundleID: bundleID),
                profileCount: offered.count,
                isExpanded: isExpanded,
                shortcut: index < 9 ? index + 1 : nil
            ))
            guard isExpanded else { continue }
            rows += offered.map {
                PickerRow(destination: Destination(bundleID: bundleID, profile: $0), profileCount: 0, isExpanded: false, shortcut: nil)
            }
        }
        return rows
    }

    private func clamped(_ index: Int) -> Int {
        min(max(index, 0), max(rows.count - 1, 0))
    }
}
