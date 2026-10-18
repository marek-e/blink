import AppKit

enum Announcer {
    /// Speaks `text` through VoiceOver without moving focus.
    @MainActor
    static func announce(_ text: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
