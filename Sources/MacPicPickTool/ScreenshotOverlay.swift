import AppKit
import CoreGraphics

// MARK: - Overlay Window

/// Full-screen borderless window that dims the display and lets the user
/// drag a selection rectangle. On mouse-up the region is captured via
/// CGWindowListCreateImage and returned through the onCapture callback.
final class ScreenshotOverlayWindow: NSWindow {
    private let selectionView: SelectionOverlayView

    // MARK: Factory

    /// Returns nil if no main screen is available (safe unwrap).
    static func makeForMainScreen() -> ScreenshotOverlayWindow? {
        // NSScreen.screens.first avoids the crash that NSScreen.screens[0] causes
        // when the array is empty (e.g. during display reconfiguration).
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        return ScreenshotOverlayWindow(screen: screen)
    }

    // MARK: Init

    private init(screen: NSScreen) {
        selectionView = SelectionOverlayView(frame: screen.frame)

        // Use the 4-parameter DESIGNATED initializer of NSWindow.
        // The 5-parameter version (with screen:) is a convenience init — calling it
        // from a subclass designated init breaks Swift's initializer chain and causes
        // EXC_BREAKPOINT / SIGTRAP at runtime.
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Prevent NSWindow from auto-releasing itself when ordered out
        isReleasedWhenClosed = false

        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = selectionView
    }

    /// NSWindow subclasses must implement this; we never decode from a xib/nib.
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ScreenshotOverlayWindow does not support init(coder:)")
    }

    // MARK: Public API

    func start(onCapture: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void) {
        selectionView.onCapture = { [weak self] rect in
            self?.orderOut(nil)
            // Wait for the overlay to fully disappear before capturing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let cgImage = CGWindowListCreateImage(
                    rect,
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    .bestResolution
                )
                if let cgImage {
                    // rect.size is in points; NSImage handles Retina pixel density
                    onCapture(NSImage(cgImage: cgImage, size: rect.size))
                } else {
                    onCancel()
                }
            }
        }
        selectionView.onCancel = { [weak self] in
            self?.orderOut(nil)
            onCancel()
        }
        makeKeyAndOrderFront(nil)
        selectionView.window?.makeFirstResponder(selectionView)
    }
}

// MARK: - Selection View

/// NSView that draws the dim overlay, selection highlight, size label,
/// and handles mouse + keyboard events.
final class SelectionOverlayView: NSView {
    var onCapture: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint = .zero
    private var currentPoint: NSPoint = .zero
    private var isSelecting = false

    // isFlipped = true → (0,0) at top-left of the view, which maps 1:1 to
    // CGWindowListCreateImage's Quartz coordinate origin (top-left of primary display).
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()

        guard isSelecting else {
            drawHint()
            return
        }

        let sel = selectionRect
        guard sel.width > 0, sel.height > 0 else { return }

        // Punch a transparent hole so real screen content shows through
        NSGraphicsContext.current?.cgContext.clear(sel)

        // Dashed white border
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: sel.insetBy(dx: 0.75, dy: 0.75))
        path.lineWidth = 1.5
        path.setLineDash([5, 3], count: 2, phase: 0)
        path.stroke()

        drawHandles(for: sel)
        drawSizeLabel(for: sel)
    }

    private func drawHint() {
        let hint = "拖曳選取截圖區域　　Esc 取消"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.85),
            .font: NSFont.systemFont(ofSize: 15, weight: .medium)
        ]
        let sz = (hint as NSString).size(withAttributes: attrs)
        (hint as NSString).draw(
            at: NSPoint(x: (bounds.width - sz.width) / 2,
                        y: (bounds.height - sz.height) / 2),
            withAttributes: attrs
        )
    }

    private func drawHandles(for rect: NSRect) {
        let sz: CGFloat = 6
        NSColor.white.setFill()
        for corner in [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.maxX, y: rect.maxY)
        ] {
            NSRect(x: corner.x - sz / 2, y: corner.y - sz / 2, width: sz, height: sz).fill()
        }
    }

    private func drawSizeLabel(for rect: NSRect) {
        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .backgroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        let sz = (label as NSString).size(withAttributes: attrs)
        let x = max(rect.minX, min(rect.maxX - sz.width, bounds.maxX - sz.width - 4))
        let y = min(rect.maxY + 5, bounds.maxY - sz.height - 4)
        (label as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    // MARK: Geometry

    var selectionRect: NSRect {
        NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    // MARK: Mouse Events

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isSelecting = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        isSelecting = false
        needsDisplay = true

        let sel = selectionRect
        if sel.width > 10, sel.height > 10 {
            onCapture?(sel)
        } else {
            onCancel?()
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            isSelecting = false
            onCancel?()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
