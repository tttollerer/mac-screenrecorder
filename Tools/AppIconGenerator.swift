import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsDirectory = root.appendingPathComponent("Assets", isDirectory: true)
let iconsetDirectory = assetsDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in outputs {
    let image = makeIcon(size: size)
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(filename)")
    }

    try pngData.write(to: iconsetDirectory.appendingPathComponent(filename))
}

func makeIcon(size: Int) -> NSImage {
    let canvasSize = NSSize(width: size, height: size)
    let image = NSImage(size: canvasSize)

    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let scale = CGFloat(size) / 1024
    let bounds = NSRect(origin: .zero, size: canvasSize)
    let cornerRadius = 224 * scale

    let basePath = NSBezierPath(roundedRect: bounds.insetBy(dx: 36 * scale, dy: 36 * scale), xRadius: cornerRadius, yRadius: cornerRadius)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.40, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.00, green: 0.72, blue: 0.82, alpha: 1)
    ])?.draw(in: basePath, angle: -35)

    NSColor(calibratedWhite: 1, alpha: 0.20).setStroke()
    basePath.lineWidth = 26 * scale
    basePath.stroke()

    let screenRect = NSRect(x: 206 * scale, y: 304 * scale, width: 612 * scale, height: 412 * scale)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 72 * scale, yRadius: 72 * scale)
    NSColor(calibratedWhite: 1, alpha: 0.93).setFill()
    screenPath.fill()

    NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.22, alpha: 0.22).setStroke()
    screenPath.lineWidth = 18 * scale
    screenPath.stroke()

    let insetRect = screenRect.insetBy(dx: 52 * scale, dy: 52 * scale)
    let insetPath = NSBezierPath(roundedRect: insetRect, xRadius: 42 * scale, yRadius: 42 * scale)
    NSColor(calibratedRed: 0.03, green: 0.11, blue: 0.18, alpha: 0.08).setFill()
    insetPath.fill()

    let dotRect = NSRect(x: 384 * scale, y: 398 * scale, width: 256 * scale, height: 256 * scale)
    NSColor(calibratedRed: 1.00, green: 0.17, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    NSColor.white.setStroke()
    let ringRect = dotRect.insetBy(dx: 64 * scale, dy: 64 * scale)
    let ringPath = NSBezierPath(ovalIn: ringRect)
    ringPath.lineWidth = 34 * scale
    ringPath.stroke()

    NSColor.white.setFill()
    NSBezierPath(ovalIn: dotRect.insetBy(dx: 104 * scale, dy: 104 * scale)).fill()

    return image
}
