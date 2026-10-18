import CoreGraphics

/// Where the picker appears. Pure geometry in AppKit's bottom-left-origin screen coordinates.
public enum PickerPlacement {
    public struct Screen: Equatable, Sendable {
        public var frame: CGRect
        /// The frame minus the menu bar and Dock.
        public var visibleFrame: CGRect

        public init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame
        }
    }

    public static let margin: CGFloat = 8
    /// How far above the pointer the picker's top edge sits.
    public static let pointerOffset: CGFloat = 24

    /// Centers the picker horizontally on the pointer, just below it, on the screen that contains
    /// the pointer (or the first screen), fully inside that screen's visible area.
    public static func frame(size: CGSize, pointer: CGPoint, screens: [Screen]) -> CGRect {
        let origin = CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height + pointerOffset)
        let proposed = CGRect(origin: origin, size: size)
        guard let screen = screen(containing: pointer, in: screens) else { return proposed }
        return clamp(proposed, into: screen)
    }

    /// Keeps `frame` inside the visible area of `screen`, shrinking it if it can't fit.
    public static func clamp(_ frame: CGRect, into screen: Screen) -> CGRect {
        let visible = screen.visibleFrame.insetBy(dx: margin, dy: margin)
        var result = frame
        result.size.width = min(result.width, visible.width)
        result.size.height = min(result.height, visible.height)
        result.origin.x = min(max(result.minX, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        return result
    }

    public static func screen(containing point: CGPoint, in screens: [Screen]) -> Screen? {
        // NSMouseInRect semantics: the top and right edges belong to the screen.
        screens.first { $0.frame.minX <= point.x && point.x <= $0.frame.maxX && $0.frame.minY <= point.y && point.y <= $0.frame.maxY }
            ?? screens.first
    }
}

/// Picker keyboard commands, mapped from physical key codes so digit shortcuts work on every
/// layout (on AZERTY the top row types digits only with Shift).
public enum PickerKey: Equatable, Sendable {
    case up, down, open
    /// Show (→) or hide (←) a browser's profiles.
    case expand, collapse
    case digit(Int)

    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    /// - Parameter hasCommandModifier: whether Command, Option, or Control is held. Those
    ///   combinations belong to menus and text editing, never the picker.
    public init?(keyCode: UInt16, hasCommandModifier: Bool) {
        guard !hasCommandModifier else { return nil }
        switch keyCode {
        case 126: self = .up
        case 125: self = .down
        case 124: self = .expand
        case 123: self = .collapse
        case 36, 76: self = .open
        default:
            guard let digit = Self.digitKeyCodes[keyCode] else { return nil }
            self = .digit(digit)
        }
    }
}
