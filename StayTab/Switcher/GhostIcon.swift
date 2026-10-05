import AppKit

/// "Not running" look for a launchable row — mainly a pinned app that has quit
/// but keeps its slot: the app icon, dimmed, inside a dashed rounded frame. It is
/// drawn once per bundle into `IconCache`, so the hot path only blits a bitmap.
enum GhostIcon {
    /// How much of the real icon shows through. Low enough to read as "empty
    /// slot", high enough that the app stays recognizable.
    static let iconAlpha: CGFloat = 0.55

    struct Geometry: Equatable {
        let frame: CGRect
        let cornerRadius: CGFloat
        let lineWidth: CGFloat
        let dash: [CGFloat]
        let iconRect: CGRect
    }

    /// Layout for a square canvas of `edge`. The frame is inset by half the
    /// stroke so the dashes are never clipped by the canvas.
    static func geometry(edge: CGFloat) -> Geometry {
        let lineWidth = edge * 0.03
        let inset = edge * 0.04 + lineWidth / 2
        let iconInset = edge * 0.16
        return Geometry(
            frame: CGRect(x: inset, y: inset, width: edge - inset * 2, height: edge - inset * 2),
            cornerRadius: edge * 0.225,
            lineWidth: lineWidth,
            dash: [edge * 0.06, edge * 0.05],
            iconRect: CGRect(x: iconInset, y: iconInset, width: edge - iconInset * 2, height: edge - iconInset * 2)
        )
    }

    /// Draw the ghost into the current graphics context. A mid-grey stroke reads
    /// on both the light and dark panel materials; a dynamic color would be
    /// resolved once and then served stale from the cache.
    static func draw(_ icon: NSImage, in size: NSSize) {
        let g = geometry(edge: size.width)
        icon.draw(in: g.iconRect, from: .zero, operation: .sourceOver, fraction: iconAlpha)
        let path = NSBezierPath(roundedRect: g.frame, xRadius: g.cornerRadius, yRadius: g.cornerRadius)
        path.lineWidth = g.lineWidth
        path.setLineDash(g.dash, count: g.dash.count, phase: 0)
        path.lineCapStyle = .round
        NSColor(white: 0.55, alpha: 0.9).setStroke()
        path.stroke()
    }
}
