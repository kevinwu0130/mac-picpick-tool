import SwiftUI
import AppKit

class AnnotationStore: ObservableObject {
    @Published var selectedImage: NSImage?
    @Published var rectangles: [RectAnnotation] = []
    @Published var textAnnotations: [TextAnnotation] = []
    @Published var currentTool: AnnotationTool = .rectangle

    var hasAnnotations: Bool {
        !rectangles.isEmpty || !textAnnotations.isEmpty
    }

    func loadImage(from url: URL) {
        selectedImage = NSImage(contentsOf: url)
        rectangles = []
        textAnnotations = []
    }

    func addRectangle(_ rect: CGRect) {
        rectangles.append(RectAnnotation(rect: rect))
    }

    func addText(_ text: String, at position: CGPoint) {
        textAnnotations.append(TextAnnotation(position: position, text: text))
    }

    func undo() {
        if !textAnnotations.isEmpty {
            textAnnotations.removeLast()
        } else if !rectangles.isEmpty {
            rectangles.removeLast()
        }
    }

    func clearAnnotations() {
        rectangles = []
        textAnnotations = []
    }

    // Composites annotations onto the original image at full resolution.
    func exportAnnotatedImage(canvasSize: CGSize) -> NSImage? {
        guard let original = selectedImage else { return nil }
        guard canvasSize.width > 0, canvasSize.height > 0 else { return original }

        let imgSize = original.size
        let result = NSImage(size: imgSize)
        result.lockFocus()
        defer { result.unlockFocus() }

        original.draw(in: NSRect(origin: .zero, size: imgSize))

        let scaleX = imgSize.width / canvasSize.width
        let scaleY = imgSize.height / canvasSize.height
        let lineScale = max(scaleX, scaleY)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return result }

        // Rectangles
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineWidth(2.0 * lineScale)
        for rect in rectangles {
            // SwiftUI canvas: y=0 at top; NSImage context: y=0 at bottom
            let r = CGRect(
                x: rect.rect.minX * scaleX,
                y: imgSize.height - rect.rect.maxY * scaleY,
                width: rect.rect.width * scaleX,
                height: rect.rect.height * scaleY
            )
            ctx.stroke(r)
        }

        // Text
        for annotation in textAnnotations {
            let fontSize = 16.0 * lineScale
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.red,
                .backgroundColor: NSColor.black.withAlphaComponent(0.55)
            ]
            let pt = CGPoint(
                x: annotation.position.x * scaleX,
                y: imgSize.height - annotation.position.y * scaleY - fontSize
            )
            (annotation.text as NSString).draw(at: pt, withAttributes: attrs)
        }

        return result
    }
}
