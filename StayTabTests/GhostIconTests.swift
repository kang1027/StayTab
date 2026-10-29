import AppKit
import Testing
@testable import StayTab

/// The dashed "not running" icon for launchable (closed pinned) rows.
@Suite("Ghost icon")
struct GhostIconTests {

    @Test("frame and icon stay inside the canvas and the frame clears the stroke")
    func geometryStaysInsideCanvas() {
        let edge: CGFloat = 256
        let g = GhostIcon.geometry(edge: edge)
        let canvas = CGRect(x: 0, y: 0, width: edge, height: edge)
        #expect(canvas.contains(g.frame))
        #expect(canvas.contains(g.iconRect))
        #expect(g.frame.minX >= g.lineWidth / 2)
        #expect(g.frame.contains(g.iconRect))
    }

    @Test("geometry scales linearly with the canvas")
    func geometryScales() {
        let small = GhostIcon.geometry(edge: 100)
        let large = GhostIcon.geometry(edge: 200)
        #expect(abs(large.lineWidth - small.lineWidth * 2) < 0.0001)
        #expect(abs(large.frame.width - small.frame.width * 2) < 0.0001)
    }

    @Test("draw strokes the frame and leaves the canvas corner transparent")
    func drawLeavesCornerTransparent() throws {
        let edge = 128
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: edge, pixelsHigh: edge,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let ctx = try #require(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        GhostIcon.draw(NSImage(size: NSSize(width: 16, height: 16)), in: NSSize(width: edge, height: edge))
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let corner = try #require(rep.colorAt(x: 0, y: 0))
        #expect(corner.alphaComponent == 0)
        let strokeInset = Int(GhostIcon.geometry(edge: CGFloat(edge)).frame.minX)
        let alphas = (0..<edge).compactMap { rep.colorAt(x: $0, y: strokeInset)?.alphaComponent }
        #expect(alphas.contains { $0 > 0.5 })
    }
}
