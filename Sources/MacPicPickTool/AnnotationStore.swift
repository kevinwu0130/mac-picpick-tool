import SwiftUI
import AppKit
import CoreImage

class AnnotationStore: ObservableObject {
    @Published var selectedImage: NSImage?
    @Published var rectangles: [RectAnnotation] = []
    @Published var textAnnotations: [TextAnnotation] = []
    @Published var doodles: [DoodleAnnotation] = []
    @Published var mosaics: [MosaicAnnotation] = []
    @Published var blurs: [BlurAnnotation] = []
    @Published var numberLabels: [NumberLabelAnnotation] = []
    @Published var currentTool: AnnotationTool = .rectangle

    private var history: [AnnotationKind] = []

    var hasAnnotations: Bool {
        !rectangles.isEmpty || !textAnnotations.isEmpty || !doodles.isEmpty
            || !mosaics.isEmpty || !blurs.isEmpty || !numberLabels.isEmpty
    }

    var nextLabelNumber: Int { numberLabels.count + 1 }

    // MARK: - Image Loading

    func loadImage(from url: URL) {
        selectedImage = NSImage(contentsOf: url)
        clearAnnotations()
    }

    func loadImage(nsImage: NSImage) {
        selectedImage = nsImage
        clearAnnotations()
    }

    // MARK: - Adding Annotations

    func addRectangle(_ rect: CGRect) {
        rectangles.append(RectAnnotation(rect: rect))
        history.append(.rectangle)
    }

    func addText(_ text: String, at position: CGPoint) {
        textAnnotations.append(TextAnnotation(position: position, text: text))
        history.append(.text)
    }

    func addDoodle(points: [CGPoint]) {
        guard points.count > 1 else { return }
        doodles.append(DoodleAnnotation(points: points))
        history.append(.doodle)
    }

    func addMosaic(rect: CGRect, canvasSize: CGSize) {
        guard let image = selectedImage, rect.width > 5, rect.height > 5 else { return }
        guard let tile = Self.pixelateTile(from: image, canvasRect: rect, canvasSize: canvasSize, blockSize: 14)
        else { return }
        mosaics.append(MosaicAnnotation(rect: rect, tile: tile))
        history.append(.mosaic)
    }

    func addBlur(rect: CGRect, canvasSize: CGSize) {
        guard let image = selectedImage, rect.width > 5, rect.height > 5 else { return }
        guard let tile = Self.gaussianBlurTile(from: image, canvasRect: rect, canvasSize: canvasSize)
        else { return }
        blurs.append(BlurAnnotation(rect: rect, tile: tile))
        history.append(.blur)
    }

    func addNumberLabel(at position: CGPoint) {
        numberLabels.append(NumberLabelAnnotation(position: position, number: nextLabelNumber))
        history.append(.numberLabel)
    }

    // MARK: - Undo / Clear

    func undo() {
        guard let last = history.popLast() else { return }
        switch last {
        case .rectangle:   rectangles.removeLast()
        case .text:        textAnnotations.removeLast()
        case .doodle:      doodles.removeLast()
        case .mosaic:      mosaics.removeLast()
        case .blur:        blurs.removeLast()
        case .numberLabel: numberLabels.removeLast()
        }
    }

    func clearAnnotations() {
        rectangles = []
        textAnnotations = []
        doodles = []
        mosaics = []
        blurs = []
        numberLabels = []
        history = []
    }

    // MARK: - Mosaic Tile Computation

    // Crops the image region, applies CIPixellate, returns an NSImage sized for display.
    // canvasRect is in SwiftUI top-left origin coordinates; NSImage uses bottom-left origin.
    static func pixelateTile(
        from image: NSImage,
        canvasRect: CGRect,
        canvasSize: CGSize,
        blockSize: CGFloat
    ) -> NSImage? {
        guard canvasSize.width > 0, canvasSize.height > 0,
              canvasRect.width > 0, canvasRect.height > 0 else { return nil }

        let scaleX = image.size.width / canvasSize.width
        let scaleY = image.size.height / canvasSize.height

        // Source rect in NSImage coordinates (y=0 at bottom)
        let srcRect = NSRect(
            x: canvasRect.minX * scaleX,
            y: image.size.height - canvasRect.maxY * scaleY,
            width: canvasRect.width * scaleX,
            height: canvasRect.height * scaleY
        )
        guard srcRect.width > 0, srcRect.height > 0 else { return nil }

        // Extract the region by drawing into a temporary NSImage
        let crop = NSImage(size: srcRect.size)
        crop.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: srcRect.size),
            from: srcRect,
            operation: .copy,
            fraction: 1.0
        )
        crop.unlockFocus()

        // Apply CIPixellate filter
        guard let cgImg = crop.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ciImage = CIImage(cgImage: cgImg)
        let filter = CIFilter(name: "CIPixellate")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(max(8, blockSize) as NSNumber, forKey: kCIInputScaleKey)
        guard let output = filter.outputImage else { return nil }
        let ciCtx = CIContext()
        guard let outCG = ciCtx.createCGImage(output, from: output.extent) else { return nil }

        // Size the returned NSImage to the canvas rect so it draws 1:1 in the overlay
        return NSImage(cgImage: outCG, size: canvasRect.size)
    }

    // MARK: - Gaussian Blur Tile Computation

    // Applies CIGaussianBlur to the selected region. Uses clampedToExtent so edge
    // pixels repeat into the blur kernel rather than bleeding to transparent black.
    static func gaussianBlurTile(
        from image: NSImage,
        canvasRect: CGRect,
        canvasSize: CGSize,
        radius: CGFloat = 20
    ) -> NSImage? {
        guard canvasSize.width > 0, canvasSize.height > 0,
              canvasRect.width > 0, canvasRect.height > 0 else { return nil }

        guard let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let imgW = CGFloat(cgImg.width)
        let imgH = CGFloat(cgImg.height)
        let scaleX = imgW / canvasSize.width
        let scaleY = imgH / canvasSize.height

        // CIImage uses bottom-left origin (same as CGImage)
        let srcRect = CGRect(
            x: canvasRect.minX * scaleX,
            y: imgH - canvasRect.maxY * scaleY,
            width: canvasRect.width * scaleX,
            height: canvasRect.height * scaleY
        )
        guard srcRect.width > 0, srcRect.height > 0 else { return nil }

        let ciImage = CIImage(cgImage: cgImg)
        // clampedToExtent repeats edge pixels into the blur kernel, avoiding black borders
        let clamped = ciImage.clampedToExtent()
        let filter = CIFilter(name: "CIGaussianBlur")!
        filter.setValue(clamped, forKey: kCIInputImageKey)
        filter.setValue(radius as NSNumber, forKey: kCIInputRadiusKey)
        guard let blurred = filter.outputImage else { return nil }

        let ctx = CIContext()
        guard let outCG = ctx.createCGImage(blurred, from: srcRect) else { return nil }
        return NSImage(cgImage: outCG, size: canvasRect.size)
    }

    // MARK: - Full-Resolution Export

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

        // 1. Mosaics — re-pixelate at full image resolution for crisp export
        for mosaic in mosaics {
            let destRect = CGRect(
                x: mosaic.rect.minX * scaleX,
                y: imgSize.height - mosaic.rect.maxY * scaleY,
                width: mosaic.rect.width * scaleX,
                height: mosaic.rect.height * scaleY
            )
            if let hiRes = Self.pixelateTile(
                from: original,
                canvasRect: mosaic.rect,
                canvasSize: canvasSize,
                blockSize: 20 * lineScale
            ) {
                hiRes.draw(in: destRect)
            }
        }

        // 2. Blurs — re-blur at full image resolution
        for blur in blurs {
            let destRect = CGRect(
                x: blur.rect.minX * scaleX,
                y: imgSize.height - blur.rect.maxY * scaleY,
                width: blur.rect.width * scaleX,
                height: blur.rect.height * scaleY
            )
            if let hiRes = Self.gaussianBlurTile(
                from: original,
                canvasRect: blur.rect,
                canvasSize: canvasSize,
                radius: 20
            ) {
                hiRes.draw(in: destRect)
            }
        }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return result }

        // 3. Rectangles
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineWidth(2.0 * lineScale)
        for rect in rectangles {
            let r = CGRect(
                x: rect.rect.minX * scaleX,
                y: imgSize.height - rect.rect.maxY * scaleY,
                width: rect.rect.width * scaleX,
                height: rect.rect.height * scaleY
            )
            ctx.stroke(r)
        }

        // 4. Doodles
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(3.0 * lineScale)
        for doodle in doodles {
            guard doodle.points.count > 1 else { continue }
            ctx.beginPath()
            let first = doodle.points[0]
            ctx.move(to: CGPoint(x: first.x * scaleX, y: imgSize.height - first.y * scaleY))
            for pt in doodle.points.dropFirst() {
                ctx.addLine(to: CGPoint(x: pt.x * scaleX, y: imgSize.height - pt.y * scaleY))
            }
            ctx.strokePath()
        }

        // 5. Text annotations
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

        // 6. Number labels — red circle with white number
        for label in numberLabels {
            let center = CGPoint(
                x: label.position.x * scaleX,
                y: imgSize.height - label.position.y * scaleY
            )
            let diameter = 26.0 * lineScale
            let circleRect = CGRect(
                x: center.x - diameter / 2,
                y: center.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            ctx.setFillColor(NSColor.red.cgColor)
            ctx.fillEllipse(in: circleRect)

            let fontSize = 14.0 * lineScale
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.white
            ]
            let str = "\(label.number)" as NSString
            let strSize = str.size(withAttributes: attrs)
            let textPt = CGPoint(
                x: center.x - strSize.width / 2,
                y: center.y - strSize.height / 2
            )
            str.draw(at: textPt, withAttributes: attrs)
        }

        return result
    }
}
