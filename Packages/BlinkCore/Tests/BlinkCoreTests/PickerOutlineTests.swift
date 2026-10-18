import Testing
@testable import BlinkCore

@Suite("Picker outline")
struct PickerOutlineTests {
    let spaces = [ProfileReference(id: "s1", name: "Work"), ProfileReference(id: "s2", name: "Home")]

    private func outline(expanded: Set<String> = [], selection: Int = 0) -> PickerOutline {
        PickerOutline(browsers: ["arc", "dia", "safari"], profiles: ["arc": spaces, "dia": []], expanded: expanded, selection: selection)
    }

    @Test func listsBrowsersWithProfilesUnderExpandedOnes() {
        #expect(outline().rows.map(\.id) == ["arc", "dia", "safari"])
        #expect(outline().rows.map(\.profileCount) == [2, 0, 0])
        let expanded = outline(expanded: ["arc", "dia", "unknown"])
        #expect(expanded.expanded == ["arc"])
        #expect(expanded.rows.map(\.id) == ["arc", "arc\u{1F}s1", "arc\u{1F}s2", "dia", "safari"])
        #expect(expanded.rows[1].destination == Destination(bundleID: "arc", profile: spaces[0]))
    }

    @Test func numberKeysAddressBrowsersOnly() {
        let expanded = outline(expanded: ["arc"])
        #expect(expanded.rows.map(\.shortcut) == [1, nil, nil, 2, 3])
        #expect(expanded.index(forShortcut: 2) == 3)
        #expect(expanded.index(forShortcut: 4) == nil)
    }

    @Test func rightArrowExpandsThenEntersProfiles() {
        var picker = outline()
        picker.expandSelection()
        #expect(picker.expanded == ["arc"])
        #expect(picker.selectedRow?.destination.profile == spaces[0])
        picker.expandSelection()
        #expect(picker.selection == 1)

        var plain = outline(selection: 1)
        plain.expandSelection()
        #expect(plain.expanded.isEmpty)
        #expect(plain.selection == 1)
    }

    @Test func rightArrowOnExpandedBrowserMovesIntoProfiles() {
        var picker = outline(expanded: ["arc"])
        picker.expandSelection()
        #expect(picker.selection == 1)
    }

    @Test func leftArrowReturnsToTheBrowser() {
        var picker = outline(expanded: ["arc"], selection: 2)
        picker.collapseSelection()
        #expect(picker.expanded.isEmpty)
        #expect(picker.selectedRow?.id == "arc")

        var browser = outline(expanded: ["arc"], selection: 0)
        browser.collapseSelection()
        #expect(browser.expanded.isEmpty)
        #expect(browser.selection == 0)

        var other = outline(expanded: ["arc"], selection: 3)
        other.collapseSelection()
        #expect(other.expanded == ["arc"])
    }

    @Test func toggleKeepsTheSelectedRow() {
        var picker = outline(selection: 2)
        picker.toggle("arc")
        #expect(picker.selectedRow?.id == "safari")
        #expect(picker.selection == 4)
        picker.toggle("arc")
        #expect(picker.selectedRow?.id == "safari")
        picker.toggle("dia")
        #expect(picker.expanded.isEmpty)
    }

    @Test func movingWrapsAroundAllRows() {
        var picker = outline(expanded: ["arc"])
        picker.move(by: -1)
        #expect(picker.selectedRow?.id == "safari")
        picker.move(by: 1)
        picker.move(by: 1)
        #expect(picker.selectedRow?.id == "arc\u{1F}s1")
        var empty = PickerOutline(browsers: [], profiles: [:], selection: 3)
        empty.move(by: 1)
        #expect(empty.selection == 0)
        #expect(empty.selectedRow == nil)
    }

    @Test func clampsSelection() {
        #expect(outline(selection: 10).selection == 2)
        #expect(outline(selection: -1).selection == 0)
    }
}
