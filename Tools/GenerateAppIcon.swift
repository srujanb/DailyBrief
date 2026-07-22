import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: swift Tools/GenerateAppIcon.swift <output-iconset-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: CGFloat)] = [
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

for iconFile in iconFiles {
    let size = NSSize(width: iconFile.pixels, height: iconFile.pixels)
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(iconFile.pixels),
        pixelsHigh: Int(iconFile.pixels),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap representation for \(iconFile.name)")
    }

    representation.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    drawIcon(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(iconFile.name)")
    }

    try data.write(to: outputDirectory.appendingPathComponent(iconFile.name))
}

private func drawIcon(in rect: NSRect) {
    NSColor.clear.setFill()
    rect.fill()

    let inset = rect.width * 0.105
    let tileRect = rect.insetBy(dx: inset, dy: inset)
    let tileRadius = rect.width * 0.205

    let backgroundPath = NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius)
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    backgroundPath.fill()

    NSColor(calibratedWhite: 0.18, alpha: 1).setStroke()
    let borderPath = NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius)
    borderPath.lineWidth = max(1, rect.width * 0.012)
    borderPath.stroke()

    drawSunriseNote(in: rect)
}

private func drawSunriseNote(in rect: NSRect) {
    let lineScale = rect.width / 18

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + x * lineScale, y: rect.minY + y * lineScale)
    }

    func scaledRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(
            x: rect.minX + x * lineScale,
            y: rect.minY + y * lineScale,
            width: width * lineScale,
            height: height * lineScale
        )
    }

    NSColor(calibratedWhite: 0.2, alpha: 1).setStroke()

    let lineWidth = max(1.2, 1.45 * lineScale)
    let sunPath = NSBezierPath()
    sunPath.lineWidth = lineWidth
    sunPath.lineCapStyle = .round
    sunPath.appendArc(
        withCenter: point(9, 9.9),
        radius: 3.35 * lineScale,
        startAngle: 0,
        endAngle: 180
    )
    sunPath.stroke()

    let rays: [(NSPoint, NSPoint)] = [
        (NSPoint(x: 9, y: 14.4), NSPoint(x: 9, y: 16)),
        (NSPoint(x: 5.4, y: 13.2), NSPoint(x: 4.2, y: 14.4)),
        (NSPoint(x: 12.6, y: 13.2), NSPoint(x: 13.8, y: 14.4))
    ]

    for ray in rays {
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: point(ray.0.x, ray.0.y))
        path.line(to: point(ray.1.x, ray.1.y))
        path.stroke()
    }

    let noteRect = scaledRect(x: 4.1, y: 2.6, width: 9.8, height: 7.4)
    let notePath = NSBezierPath(
        roundedRect: noteRect,
        xRadius: 1.5 * lineScale,
        yRadius: 1.5 * lineScale
    )
    notePath.lineWidth = lineWidth
    notePath.stroke()

    let textLineWidth = max(1, 1.25 * lineScale)
    let textLines: [(CGFloat, CGFloat)] = [
        (8.0, 8.0),
        (8.0, 5.9)
    ]

    for line in textLines {
        let path = NSBezierPath()
        path.lineWidth = textLineWidth
        path.lineCapStyle = .round
        path.move(to: point(6.3, line.0))
        path.line(to: point(11.7, line.1))
        path.stroke()
    }
}
