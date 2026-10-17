import AppKit

// Renders Blink's app icon into an asset catalog icon set.
// Usage: scripts/generate-icon.sh (compiles this file together with BlinkGlyph.swift).

let outputDirectory = URL(filePath: CommandLine.arguments[1], directoryHint: .isDirectory)

func renderIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // Apple's macOS icon grid: an 824-point rounded square centered on a 1024 canvas.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(srgbRed: 0.31, green: 0.27, blue: 0.9, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [
        NSColor(srgbRed: 0.56, green: 0.36, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.29, green: 0.33, blue: 0.95, alpha: 1),
        NSColor(srgbRed: 0.12, green: 0.42, blue: 0.93, alpha: 1),
    ])!.draw(in: tile, angle: -60)
    NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.2), 0),
        (NSColor.white.withAlphaComponent(0), 0.55)
    )!.draw(in: tile, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.18).setStroke()
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    rim.lineWidth = 4
    rim.stroke()

    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    glow.shadowBlurRadius = 18
    glow.shadowOffset = NSSize(width: 0, height: -6)
    glow.set()
    BlinkGlyph.draw(in: tile.insetBy(dx: 150, dy: 150), color: .white, dimmedAlpha: 0.42)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

struct Entry: Encodable {
    let size: String
    let idiom = "mac"
    let filename: String
    let scale: String
}

var images: [Entry] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try renderIcon(pixels: points * scale).write(to: outputDirectory.appending(path: filename))
        images.append(Entry(size: "\(points)x\(points)", filename: filename, scale: "\(scale)x"))
    }
}
struct Contents: Encodable {
    struct Info: Encodable { let version = 1; let author = "xcode" }
    let images: [Entry]
    let info = Info()
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(Contents(images: images)).write(to: outputDirectory.appending(path: "Contents.json"))
print("Wrote \(images.count) icon images to \(outputDirectory.path)")
