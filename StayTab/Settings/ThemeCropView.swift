import AppKit

/// The whole picture with a frame over the part an area shows. Dragging the
/// frame (or the arrow keys) moves the focus; dropping an image file on it
/// replaces the picture.
final class ThemeCropView: NSView {
    var image: CGImage? { didSet { needsDisplay = true } }
    var focus = CGPoint(x: 0.5, y: 0.5) { didSet { needsDisplay = true } }
    var zoom: CGFloat = 1 { didSet { needsDisplay = true } }
    /// Width / height of the area the picture fills.
    var areaAspect: CGFloat = 2 { didSet { needsDisplay = true } }

    var onFocusChange: ((CGPoint) -> Void)?
    var onDropFile: ((URL) -> Void)?

    private var dragStart: (point: NSPoint, center: CGPoint)?
    private var isDropTarget = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Visible area"))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override var acceptsFirstResponder: Bool { image != nil }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill() }

    /// Letterboxed rect of the whole picture inside the view.
    private var imageRect: NSRect {
        guard let image, image.width > 0, image.height > 0 else { return bounds }
        let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
        let size = NSSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        return NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    private var frameUnitRect: CGRect {
        guard let image else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        return ThemeCrop.visibleRect(
            imageSize: CGSize(width: image.width, height: image.height),
            viewSize: CGSize(width: areaAspect, height: 1),
            focus: focus, zoom: zoom
        )
    }

    /// `frameUnitRect` (top-left unit space) in view coordinates.
    private var frameRect: NSRect {
        let box = imageRect, unit = frameUnitRect
        return NSRect(x: box.minX + unit.minX * box.width,
                      y: box.maxY - unit.maxY * box.height,
                      width: unit.width * box.width,
                      height: unit.height * box.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let clip = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.quaternaryLabelColor.setFill()
        clip.fill()
        guard let image, let context = NSGraphicsContext.current?.cgContext else {
            drawPrompt()
            return
        }
        context.saveGState()
        clip.addClip()
        context.interpolationQuality = .medium
        context.draw(image, in: imageRect)
        let frame = frameRect
        let shade = NSBezierPath(rect: bounds)
        shade.append(NSBezierPath(rect: frame))
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.5).setFill()
        shade.fill()
        context.restoreGState()
        let outline = NSBezierPath(roundedRect: frame.insetBy(dx: 0.75, dy: 0.75), xRadius: 3, yRadius: 3)
        outline.lineWidth = 1.5
        NSColor.white.setStroke()
        outline.stroke()
        if isDropTarget { drawDropHighlight() }
    }

    private func drawPrompt() {
        let text = String(localized: "Drop a picture here") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
        if isDropTarget { drawDropHighlight() }
    }

    private func drawDropHighlight() {
        let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        ring.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        ring.stroke()
    }

    // MARK: - Moving the frame

    override func mouseDown(with event: NSEvent) {
        guard image != nil else { return }
        window?.makeFirstResponder(self)
        let unit = frameUnitRect
        dragStart = (convert(event.locationInWindow, from: nil), CGPoint(x: unit.midX, y: unit.midY))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let box = imageRect
        guard box.width > 0, box.height > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        move(to: CGPoint(x: dragStart.center.x + (point.x - dragStart.point.x) / box.width,
                         y: dragStart.center.y - (point.y - dragStart.point.y) / box.height))
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }

    override func keyDown(with event: NSEvent) {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 0.1 : 0.02
        let unit = frameUnitRect
        var center = CGPoint(x: unit.midX, y: unit.midY)
        switch event.specialKey {
        case .leftArrow?: center.x -= step
        case .rightArrow?: center.x += step
        case .upArrow?: center.y -= step
        case .downArrow?: center.y += step
        default:
            super.keyDown(with: event)
            return
        }
        move(to: center)
    }

    /// Stores the clamped center, so the focus never sits beyond what the frame
    /// can reach and the next drag starts where the frame is.
    private func move(to center: CGPoint) {
        focus = CGPoint(x: center.x.clamped(to: 0...1), y: center.y.clamped(to: 0...1))
        let unit = frameUnitRect
        focus = CGPoint(x: (unit.midX * 1000).rounded() / 1000, y: (unit.midY * 1000).rounded() / 1000)
        onFocusChange?(focus)
    }

    // MARK: - Dropping a file

    private func imageURL(from info: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingContentsConformToTypes: ["public.image"]]
        return (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard imageURL(from: sender) != nil else { return [] }
        isDropTarget = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropTarget = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropTarget = false
        guard let url = imageURL(from: sender) else { return false }
        onDropFile?(url)
        return true
    }
}

/// A round color chip for a theme preset.
final class ThemeSwatchButton: NSButton {
    let fillColor: NSColor
    var isChosen = false { didSet { needsDisplay = true } }

    init(color: NSColor, name: String) {
        fillColor = color
        super.init(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        isBordered = false
        title = ""
        toolTip = name
        setAccessibilityLabel(name)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 22).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = isChosen ? 4 : 2
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
        fillColor.setFill()
        circle.fill()
        NSColor.separatorColor.setStroke()
        circle.lineWidth = 0.5
        circle.stroke()
        if isChosen {
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
            ring.lineWidth = 1.5
            NSColor.controlAccentColor.setStroke()
            ring.stroke()
        }
    }
}
