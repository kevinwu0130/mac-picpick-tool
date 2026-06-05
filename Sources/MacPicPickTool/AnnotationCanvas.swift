import SwiftUI
import AppKit

struct AnnotationCanvas: View {
    @ObservedObject var store: AnnotationStore
    @Binding var showTextInput: Bool
    @Binding var textInputPosition: CGPoint
    @Binding var canvasSize: CGSize
    @Binding var selectedKind: AnnotationKind?
    @Binding var selectedIndex: Int
    @Binding var zoomScale: CGFloat

    // Drag state for shape tools
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var isDrawingShape = false

    // Doodle stroke
    @State private var currentStroke: [CGPoint] = []

    // Move state (during active drag)
    @State private var isMoving = false
    @State private var moveStart: CGPoint = .zero
    @State private var moveCurrent: CGPoint = .zero

    @State private var isHovering = false

    // Base canvas size captured before zoom (annotation coordinate space)
    @State private var baseCanvasSize: CGSize = .zero

    private var moveDelta: CGSize {
        CGSize(width: moveCurrent.x - moveStart.x, height: moveCurrent.y - moveStart.y)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let image = store.selectedImage {
                let hasBase = baseCanvasSize.width > 0
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    // Fix layout size to baseCanvasSize when zoomed to prevent coordinate drift
                    .frame(
                        width: hasBase ? baseCanvasSize.width : nil,
                        height: hasBase ? baseCanvasSize.height : nil
                    )
                    .overlay(canvasOverlay)
                    .scaleEffect(zoomScale, anchor: .topLeading)
                    // Give the ScrollView a content size that matches visual zoom
                    .frame(
                        minWidth: hasBase ? baseCanvasSize.width * zoomScale : nil,
                        minHeight: hasBase ? baseCanvasSize.height * zoomScale : nil,
                        alignment: .topLeading
                    )
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Overlay

    private var canvasOverlay: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                drawAll(in: context)
            }
            .contentShape(Rectangle())
            .gesture(interactionGesture)
            .onHover { hovering in
                isHovering = hovering
                updateCursor(active: hovering)
            }
            .onChange(of: store.currentTool) { _ in
                if isHovering { updateCursor(active: true) }
            }
            .onAppear {
                canvasSize = geo.size
                if baseCanvasSize == .zero { baseCanvasSize = geo.size }
            }
            .onChange(of: geo.size) { newSize in
                // Only update base when not zoomed (window resize at 1×)
                if zoomScale == 1.0 { baseCanvasSize = newSize }
                canvasSize = newSize
            }
        }
    }

    // MARK: - Drawing

    private func drawAll(in context: GraphicsContext) {
        // 1. Highlights
        for (i, h) in store.highlights.enumerated() {
            let rect = isMoving && selectedKind == .highlight && selectedIndex == i
                ? h.rect.offsetBy(dx: moveDelta.width, dy: moveDelta.height) : h.rect
            context.fill(Path(rect), with: .color(h.color.opacity(0.4)))
        }

        // 2. Mosaics
        for mosaic in store.mosaics {
            context.draw(Image(nsImage: mosaic.tile), in: mosaic.rect)
        }

        // 3. Blurs
        for blur in store.blurs {
            context.draw(Image(nsImage: blur.tile), in: blur.rect)
        }

        // 4. Ellipses
        for (i, ellipse) in store.ellipses.enumerated() {
            let rect = isMoving && selectedKind == .ellipse && selectedIndex == i
                ? ellipse.rect.offsetBy(dx: moveDelta.width, dy: moveDelta.height) : ellipse.rect
            if ellipse.filled {
                context.fill(Path(ellipseIn: rect), with: .color(ellipse.color.opacity(0.25)))
            }
            context.stroke(Path(ellipseIn: rect), with: .color(ellipse.color), lineWidth: ellipse.lineWidth)
        }

        // 5. Rectangles
        for (i, rect) in store.rectangles.enumerated() {
            let r = isMoving && selectedKind == .rectangle && selectedIndex == i
                ? rect.rect.offsetBy(dx: moveDelta.width, dy: moveDelta.height) : rect.rect
            if rect.filled {
                context.fill(Path(r), with: .color(rect.color.opacity(0.25)))
            }
            context.stroke(Path(r), with: .color(rect.color), lineWidth: rect.lineWidth)
        }

        // 6. Lines
        for (i, line) in store.lines.enumerated() {
            let d = isMoving && selectedKind == .line && selectedIndex == i ? moveDelta : .zero
            var path = Path()
            path.move(to: line.start.offset(d.width, d.height))
            path.addLine(to: line.end.offset(d.width, d.height))
            context.stroke(path, with: .color(line.color),
                           style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round))
        }

        // 7. Arrows
        for (i, arrow) in store.arrows.enumerated() {
            let d = isMoving && selectedKind == .arrow && selectedIndex == i ? moveDelta : .zero
            drawArrow(in: context,
                      from: arrow.start.offset(d.width, d.height),
                      to: arrow.end.offset(d.width, d.height),
                      color: arrow.color, lineWidth: arrow.lineWidth)
        }

        // 8. Doodles
        for (i, doodle) in store.doodles.enumerated() {
            guard doodle.points.count > 1 else { continue }
            let d = isMoving && selectedKind == .doodle && selectedIndex == i ? moveDelta : .zero
            var path = Path()
            path.move(to: doodle.points[0].offset(d.width, d.height))
            for pt in doodle.points.dropFirst() { path.addLine(to: pt.offset(d.width, d.height)) }
            context.stroke(path, with: .color(doodle.color),
                           style: StrokeStyle(lineWidth: doodle.lineWidth, lineCap: .round, lineJoin: .round))
        }

        // 9. Text
        for (i, annotation) in store.textAnnotations.enumerated() {
            let d = isMoving && selectedKind == .text && selectedIndex == i ? moveDelta : .zero
            context.draw(
                Text(annotation.text)
                    .font(.system(size: annotation.fontSize, weight: .bold))
                    .foregroundColor(annotation.color),
                at: annotation.position.offset(d.width, d.height)
            )
        }

        // 10. Number labels
        for (i, label) in store.numberLabels.enumerated() {
            let d = isMoving && selectedKind == .numberLabel && selectedIndex == i ? moveDelta : .zero
            let pos = label.position.offset(d.width, d.height)
            let diameter: CGFloat = 26
            let circleRect = CGRect(x: pos.x - diameter / 2, y: pos.y - diameter / 2, width: diameter, height: diameter)
            context.fill(Path(ellipseIn: circleRect), with: .color(label.color))
            context.draw(
                Text("\(label.number)").font(.system(size: 14, weight: .bold)).foregroundColor(.white),
                at: pos
            )
        }

        // Live previews
        if isDrawingShape {
            switch store.currentTool {
            case .rectangle:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                if store.isFilled { context.fill(Path(preview), with: .color(store.currentColor.opacity(0.25))) }
                else { context.fill(Path(preview), with: .color(store.currentColor.opacity(0.08))) }
                context.stroke(Path(preview), with: .color(store.currentColor), lineWidth: store.currentLineWidth)
            case .ellipse:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                if store.isFilled { context.fill(Path(ellipseIn: preview), with: .color(store.currentColor.opacity(0.25))) }
                else { context.fill(Path(ellipseIn: preview), with: .color(store.currentColor.opacity(0.08))) }
                context.stroke(Path(ellipseIn: preview), with: .color(store.currentColor), lineWidth: store.currentLineWidth)
            case .line:
                var path = Path(); path.move(to: dragStart); path.addLine(to: dragCurrent)
                context.stroke(path, with: .color(store.currentColor),
                               style: StrokeStyle(lineWidth: store.currentLineWidth, lineCap: .round))
            case .arrow:
                drawArrow(in: context, from: dragStart, to: dragCurrent,
                          color: store.currentColor, lineWidth: store.currentLineWidth)
            case .highlight:
                context.fill(Path(normalizedRect(from: dragStart, to: dragCurrent)),
                             with: .color(store.currentColor.opacity(0.4)))
            case .mosaic:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                context.fill(Path(preview), with: .color(.gray.opacity(0.3)))
                context.stroke(Path(preview), with: .color(.gray), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            case .blur:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                context.fill(Path(preview), with: .color(.blue.opacity(0.15)))
                context.stroke(Path(preview), with: .color(.blue), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            default: break
            }
        }

        // Live doodle
        if currentStroke.count > 1 {
            var path = Path()
            path.move(to: currentStroke[0])
            currentStroke.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(path, with: .color(store.currentColor),
                           style: StrokeStyle(lineWidth: store.currentLineWidth, lineCap: .round, lineJoin: .round))
        }

        // Persistent selection highlight (shown at rest and during move)
        if let kind = selectedKind, selectedIndex >= 0 {
            let delta = isMoving ? moveDelta : .zero
            if let selRect = selectionBounds(kind: kind, index: selectedIndex) {
                let moved = selRect.offsetBy(dx: delta.width, dy: delta.height).insetBy(dx: -4, dy: -4)
                context.stroke(Path(moved), with: .color(.white.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                context.stroke(Path(moved), with: .color(.accentColor.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [5, 3], dashPhase: 4))
            }
        }
    }

    // MARK: - Arrow Helper

    private func drawArrow(in context: GraphicsContext, from start: CGPoint, to end: CGPoint,
                           color: Color, lineWidth: CGFloat) {
        guard hypot(end.x - start.x, end.y - start.y) > 3 else { return }
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen = lineWidth * 4 + 10
        let ha = CGFloat.pi / 6
        var path = Path()
        path.move(to: start); path.addLine(to: end)
        path.move(to: CGPoint(x: end.x - headLen * cos(angle - ha), y: end.y - headLen * sin(angle - ha)))
        path.addLine(to: end)
        path.move(to: CGPoint(x: end.x - headLen * cos(angle + ha), y: end.y - headLen * sin(angle + ha)))
        path.addLine(to: end)
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Gesture

    private var interactionGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let d = hypot(value.translation.width, value.translation.height)
                switch store.currentTool {
                case .select:
                    if !isMoving {
                        if d > 4, let (kind, index) = hitTest(at: value.startLocation) {
                            selectedKind = kind; selectedIndex = index
                            moveStart = value.startLocation; moveCurrent = value.location
                            isMoving = true
                        }
                    } else {
                        moveCurrent = value.location
                    }
                case .rectangle, .mosaic, .blur, .arrow, .line, .ellipse, .highlight:
                    if d > 3 { dragStart = value.startLocation; dragCurrent = value.location; isDrawingShape = true }
                case .doodle:
                    if currentStroke.isEmpty { currentStroke.append(value.startLocation) }
                    currentStroke.append(value.location)
                case .text, .numberLabel:
                    break
                }
            }
            .onEnded { value in
                let d = hypot(value.translation.width, value.translation.height)
                switch store.currentTool {
                case .select:
                    if isMoving, let kind = selectedKind, d > 3 {
                        store.moveAnnotation(kind: kind, index: selectedIndex, by: moveDelta)
                    }
                    isMoving = false
                    // Click on empty space → deselect
                    if d < 5, hitTest(at: value.startLocation) == nil {
                        selectedKind = nil; selectedIndex = -1
                    } else if d < 5, let hit = hitTest(at: value.startLocation) {
                        selectedKind = hit.0; selectedIndex = hit.1
                    }

                case .rectangle:
                    if d > 5 { store.addRectangle(normalizedRect(from: value.startLocation, to: value.location)) }
                    isDrawingShape = false

                case .ellipse:
                    if d > 5 { store.addEllipse(normalizedRect(from: value.startLocation, to: value.location)) }
                    isDrawingShape = false

                case .line:
                    if d > 5 { store.addLine(start: value.startLocation, end: value.location) }
                    isDrawingShape = false

                case .arrow:
                    if d > 5 { store.addArrow(start: value.startLocation, end: value.location) }
                    isDrawingShape = false

                case .highlight:
                    if d > 5 { store.addHighlight(rect: normalizedRect(from: value.startLocation, to: value.location)) }
                    isDrawingShape = false

                case .mosaic:
                    if d > 5 { store.addMosaic(rect: normalizedRect(from: value.startLocation, to: value.location), canvasSize: canvasSize) }
                    isDrawingShape = false

                case .blur:
                    if d > 5 { store.addBlur(rect: normalizedRect(from: value.startLocation, to: value.location), canvasSize: canvasSize) }
                    isDrawingShape = false

                case .doodle:
                    store.addDoodle(points: currentStroke); currentStroke = []

                case .text:
                    if d < 5 { textInputPosition = value.startLocation; showTextInput = true }

                case .numberLabel:
                    if d < 5 { store.addNumberLabel(at: value.startLocation) }
                }
            }
    }

    // MARK: - Hit Testing

    private func hitTest(at point: CGPoint) -> (AnnotationKind, Int)? {
        let r: CGFloat = 18
        for (i, l) in store.numberLabels.enumerated().reversed() {
            if hypot(l.position.x - point.x, l.position.y - point.y) < r { return (.numberLabel, i) }
        }
        for (i, t) in store.textAnnotations.enumerated().reversed() {
            if hypot(t.position.x - point.x, t.position.y - point.y) < r { return (.text, i) }
        }
        for (i, a) in store.arrows.enumerated().reversed() {
            if segmentDistance(point: point, a: a.start, b: a.end) < 10 { return (.arrow, i) }
        }
        for (i, l) in store.lines.enumerated().reversed() {
            if segmentDistance(point: point, a: l.start, b: l.end) < 10 { return (.line, i) }
        }
        for (i, d) in store.doodles.enumerated().reversed() {
            if d.points.contains(where: { hypot($0.x - point.x, $0.y - point.y) < 12 }) { return (.doodle, i) }
        }
        for (i, e) in store.ellipses.enumerated().reversed() {
            if e.rect.contains(point) { return (.ellipse, i) }
        }
        for (i, rect) in store.rectangles.enumerated().reversed() {
            if rect.rect.contains(point) { return (.rectangle, i) }
        }
        for (i, h) in store.highlights.enumerated().reversed() {
            if h.rect.contains(point) { return (.highlight, i) }
        }
        return nil
    }

    private func segmentDistance(point p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    private func selectionBounds(kind: AnnotationKind, index: Int) -> CGRect? {
        switch kind {
        case .rectangle:   return index < store.rectangles.count  ? store.rectangles[index].rect  : nil
        case .ellipse:     return index < store.ellipses.count    ? store.ellipses[index].rect    : nil
        case .highlight:   return index < store.highlights.count  ? store.highlights[index].rect  : nil
        case .arrow:
            if index < store.arrows.count {
                let a = store.arrows[index]
                return CGRect(x: min(a.start.x, a.end.x), y: min(a.start.y, a.end.y),
                              width: abs(a.end.x - a.start.x), height: abs(a.end.y - a.start.y))
            }
            return nil
        case .line:
            if index < store.lines.count {
                let l = store.lines[index]
                return CGRect(x: min(l.start.x, l.end.x), y: min(l.start.y, l.end.y),
                              width: abs(l.end.x - l.start.x), height: abs(l.end.y - l.start.y))
            }
            return nil
        case .text:
            if index < store.textAnnotations.count {
                let t = store.textAnnotations[index]
                return CGRect(x: t.position.x - 4, y: t.position.y - t.fontSize,
                              width: CGFloat(t.text.count) * t.fontSize * 0.6 + 8, height: t.fontSize + 4)
            }
            return nil
        default: return nil
        }
    }

    // MARK: - Helpers

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    private func updateCursor(active: Bool) {
        guard active else { NSCursor.arrow.set(); return }
        switch store.currentTool {
        case .select: NSCursor.arrow.set()
        case .text:   NSCursor.iBeam.set()
        default:      NSCursor.crosshair.set()
        }
    }
}
