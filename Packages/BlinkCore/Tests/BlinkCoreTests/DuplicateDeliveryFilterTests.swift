import Foundation
import Testing
@testable import BlinkCore

@Suite("Duplicate deliveries")
struct DuplicateDeliveryFilterTests {
    let link = URL(string: "https://example.com/a?b=1")!

    /// Feeds deliveries at the given offsets and returns which were dropped.
    private func dropped(_ deliveries: [(URL, Duration)]) -> [Bool] {
        let start = ContinuousClock.now
        var filter = DuplicateDeliveryFilter()
        return deliveries.map { url, offset in filter.isDuplicate(url, at: start + offset) }
    }

    @Test func dropsTheSameLinkWithinASecond() {
        #expect(dropped([(link, .zero), (link, .milliseconds(560)), (link, .milliseconds(1400))]) == [false, true, true])
    }

    @Test func keepsLaterRepeatsAndOtherLinks() {
        let other = URL(string: "https://example.com/a?b=2")!
        #expect(dropped([(link, .zero), (link, .seconds(1)), (other, .milliseconds(1100)), (link, .milliseconds(1200))])
            == [false, false, false, false])
    }
}
