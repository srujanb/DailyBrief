import AppKit

enum MenuBarIcon {
    static func sunriseNote() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()

            let lineWidth: CGFloat = 1.45

            let sunPath = NSBezierPath()
            sunPath.lineWidth = lineWidth
            sunPath.lineCapStyle = .round
            sunPath.appendArc(
                withCenter: NSPoint(x: 9, y: 9.9),
                radius: 3.35,
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
                path.move(to: ray.0)
                path.line(to: ray.1)
                path.stroke()
            }

            let notePath = NSBezierPath(roundedRect: NSRect(x: 4.1, y: 2.6, width: 9.8, height: 7.4), xRadius: 1.5, yRadius: 1.5)
            notePath.lineWidth = lineWidth
            notePath.stroke()

            let textLineWidth: CGFloat = 1.25
            let textLines: [(CGFloat, CGFloat)] = [
                (6.3, 8.0),
                (6.3, 5.9)
            ]

            for line in textLines {
                let path = NSBezierPath()
                path.lineWidth = textLineWidth
                path.lineCapStyle = .round
                path.move(to: NSPoint(x: line.0, y: line.1))
                path.line(to: NSPoint(x: 11.7, y: line.1))
                path.stroke()
            }

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "DailyBrief"
        return image
    }
}
