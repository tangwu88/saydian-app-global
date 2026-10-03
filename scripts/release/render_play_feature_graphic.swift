import AppKit
import Foundation

// Renders the Play feature graphic from the approved, unmodified SAYDIAN wordmark.
// Usage: swift scripts/release/render_play_feature_graphic.swift <repo-root>
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render_play_feature_graphic.swift <repo-root>\n", stderr)
    exit(2)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let logoURL = root.appendingPathComponent("assets/branding/saidian-logo-en.png")
let outputURL = root.appendingPathComponent("docs/release/assets/google-play/feature-graphic-en-US.jpg")
guard let logo = NSImage(contentsOf: logoURL) else {
    fputs("Approved SAYDIAN wordmark is missing\n", stderr)
    exit(1)
}

let width = 1024
let height = 500
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Could not create canvas\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high

NSColor(calibratedRed: 0.968, green: 0.981, blue: 0.989, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

// Restrained connection motif, not a depiction of any unverified hardware.
let blue = NSColor(calibratedRed: 0.13, green: 0.42, blue: 0.62, alpha: 1)
let faintBlue = NSColor(calibratedRed: 0.80, green: 0.89, blue: 0.94, alpha: 1)
for (radius, lineWidth) in [(360.0, 3.0), (250.0, 4.0), (140.0, 5.0)] {
    let circle = NSBezierPath(ovalIn: NSRect(x: 840 - radius / 2, y: 250 - radius / 2, width: radius, height: radius))
    circle.lineWidth = lineWidth
    faintBlue.setStroke()
    circle.stroke()
}
let center = NSBezierPath(ovalIn: NSRect(x: 814, y: 224, width: 52, height: 52))
blue.setFill()
center.fill()

// A white panel keeps the original black logo crisp at every display scale.
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 52, y: 70, width: 700, height: 360), xRadius: 28, yRadius: 28).fill()
logo.draw(in: NSRect(x: 104, y: 262, width: 596, height: 115), from: .zero, operation: .sourceOver, fraction: 1)

let eyebrow = NSAttributedString(
    string: "SAYDIAN HEALTH",
    attributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: blue,
        .kern: 3.2,
    ]
)
eyebrow.draw(at: NSPoint(x: 106, y: 202))

let tagline = NSAttributedString(
    string: "Everyday wellness, connected",
    attributes: [
        .font: NSFont.systemFont(ofSize: 31, weight: .medium),
        .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.21, blue: 0.25, alpha: 1),
    ]
)
tagline.draw(at: NSPoint(x: 104, y: 146))

NSGraphicsContext.restoreGraphicsState()

guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.94]) else {
    fputs("Could not encode JPEG\n", stderr)
    exit(1)
}
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try jpeg.write(to: outputURL, options: .atomic)
print(outputURL.path)
