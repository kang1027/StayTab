import AppKit

/// The specular rim of a Liquid Glass surface: a hairline stroke that is bright
/// along the top edge, nearly gone through the lower third, then picks up again
/// where light wraps the bottom corners — the way the macOS 26 HUDs and panels
/// catch light. Drawn as a gradient masked by a stroked rounded rect, because a
/// single flat color reads as a plain outline instead of glass.
///
/// Purely decorative: never takes a hit, so it can be layered over interactive
/// content as the topmost subview.
final class GlassRimView: NSView {
    /// Corner radius of the stroked outline. `nil` tracks the view's own height
    /// for a capsule. Set it to match the surface being rimmed.
    var cornerRadius: CGFloat? {
        didSet { if cornerRadius != oldValue { needsLayout = true } }
    }

    private let gradient = CAGradientLayer()
    private let stroke = CAShapeLayer()
    /// The path is rebuilt on size/radius changes only — a surface that merely
    /// moves (the tab strip's sliding capsule) keeps the one it has.
    private var pathKey: (size: NSSize, radius: CGFloat)?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        gradient.colors = [
            NSColor.white.withAlphaComponent(0.42).cgColor,
            NSColor.white.withAlphaComponent(0.20).cgColor,
            NSColor.white.withAlphaComponent(0.10).cgColor,
            NSColor.white.withAlphaComponent(0.24).cgColor,
        ]
        gradient.locations = [0, 0.32, 0.66, 1]
        // Tilted so the top-left corner leads, like the system HUD rim.
        gradient.startPoint = NSPoint(x: 0.35, y: 1)
        gradient.endPoint = NSPoint(x: 0.65, y: 0)
        stroke.fillColor = nil
        stroke.strokeColor = NSColor.black.cgColor
        stroke.lineWidth = 1
        gradient.mask = stroke
        layer?.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Manually added sublayers do not inherit the backing scale, and the mask is
    /// a rasterized shape — left at 1x the hairline goes soft on Retina.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        gradient.contentsScale = scale
        stroke.contentsScale = scale
    }

    override func layout() {
        super.layout()
        let radius = cornerRadius ?? bounds.height / 2
        guard bounds.width > 1, pathKey?.size != bounds.size || pathKey?.radius != radius else { return }
        pathKey = (bounds.size, radius)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        stroke.frame = bounds
        // Inset by half the line width so the stroke sits on the surface edge
        // instead of straddling (and getting clipped by) it.
        let outline = bounds.insetBy(dx: 0.5, dy: 0.5)
        stroke.path = CGPath(
            roundedRect: outline,
            cornerWidth: min(radius, outline.width / 2),
            cornerHeight: min(radius, outline.height / 2),
            transform: nil
        )
        CATransaction.commit()
    }
}
