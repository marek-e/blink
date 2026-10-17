import AppKit

/// Blink's mark: one link entering from the left and branching toward three destinations.
/// The app icon (scripts/IconGenerator) draws the same geometry.
enum BlinkGlyph {
    /// A template image sized for the menu bar.
    @MainActor
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(in: rect.insetBy(dx: 0.5, dy: 1.5), color: .black, dimmedAlpha: 0.45)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Blink"
        return image
    }

    /// Draws the mark scaled to `rect` in `color`. The two unchosen branches are drawn at `dimmedAlpha`.
    /// Each group is composited as one layer so overlapping strokes and shadows don't show seams.
    static func draw(in rect: NSRect, color: NSColor, dimmedAlpha: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        func dot(at center: NSPoint, radius: CGFloat) {
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
        }
        let lineWidth = rect.width * 0.1
        let dotRadius = rect.width * 0.085
        let start = point(0.14, 0.5)
        let fork = point(0.42, 0.5)
        let ends = [point(0.86, 0.84), point(0.86, 0.5), point(0.86, 0.16)]

        func branch(to end: NSPoint) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: fork)
            if end.y == fork.y {
                path.line(to: end)
            } else {
                path.curve(to: end, controlPoint1: point(0.62, 0.5), controlPoint2: NSPoint(x: point(0.62, 0).x, y: end.y))
            }
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            return path
        }

        color.setStroke()
        color.setFill()

        context.saveGState()
        context.setAlpha(dimmedAlpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        for end in ends.dropFirst() {
            branch(to: end).stroke()
            dot(at: end, radius: dotRadius)
        }
        context.endTransparencyLayer()
        context.restoreGState()

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        let stem = NSBezierPath()
        stem.move(to: start)
        stem.line(to: fork)
        stem.lineWidth = lineWidth
        stem.lineCapStyle = .round
        stem.stroke()
        branch(to: ends[0]).stroke()
        dot(at: start, radius: dotRadius * 1.25)
        dot(at: ends[0], radius: dotRadius)
        context.endTransparencyLayer()
    }
}
