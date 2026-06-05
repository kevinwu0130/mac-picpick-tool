import SwiftUI
import AppKit

struct AnnotationCanvas: View {
    @ObservedObject var store: AnnotationStore
    @Binding var showTextInput: Bool
    @Binding var textInputPosition: CGPoint
    @Binding var canvasSize: CGSize

    // Shared drag state for rect/arrow/mosaic/blur/highlight tools
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var isDrawingRect = false

    @State private var currentStroke: [CGPoint] = []
    @State private var isHovering = false

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let image = store.selectedImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(canvasOverlay)
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
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { newSize in canvasSize = newSize }
        }
    }

    // MARK: - Canvas Drawing

    private func drawAll(in context: GraphicsContext) {
        // 1. Highlights — semi-transparent fill, under all other annotations
        for h in store.highlights {
            context.fill(Path(h.rect), with: .color(h.color.opacity(0.4)))
        }

        // 2. Mosaics
        for mosaic in store.mosaics {
            context.draw(Image(nsImage: mosaic.tile), in: mosaic.rect)
        }

        // 3. Blurs
        for blur in store.blurs {
            context.draw(Image(nsImage: blur.tile), in: blur.rect)
        }

        // 4. Rectangles
        for rect in store.rectangles {
            context.stroke(Path(rect.rect), with: .color(rect.color), lineWidth: rect.lineWidth)
        }

        // 5. Arrows
        for arrow in store.arrows {
            drawArrow(in: context, from: arrow.start, to: arrow.end,
                      color: arrow.color, lineWidth: arrow.lineWidth)
        }

        // 6. Doodles
        for doodle in store.doodles {
            guard doodle.points.count > 1 else { continue }
            var path = Path()
            path.move(to: doodle.points[0])
            doodle.points.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(path, with: .color(doodle.color),
                           style: StrokeStyle(lineWidth: doodle.lineWidth, lineCap: .round, lineJoin: .round))
        }

        // 7. Text annotations
        for annotation in store.textAnnotations {
            context.draw(
                Text(annotation.text).font(.system(size: 16, weight: .bold)).foregroundColor(annotation.color),
                at: annotation.position
            )
        }

        // 8. Number labels — colored circle with white number
        for label in store.numberLabels {
            let diameter: CGFloat = 26
            let circleRect = CGRect(
                x: label.position.x - diameter / 2,
                y: label.position.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(Path(ellipseIn: circleRect), with: .color(label.color))
            context.draw(
                Text("\(label.number)").font(.system(size: 14, weight: .bold)).foregroundColor(.white),
                at: label.position
            )
        }

        // 9. Live previews
        if isDrawingRect {
            switch store.currentTool {
            case .rectangle:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                let path = Path(preview)
                context.fill(path, with: .color(store.currentColor.opacity(0.1)))
                context.stroke(path, with: .color(store.currentColor), lineWidth: store.currentLineWidth)
            case .arrow:
                drawArrow(in: context, from: dragStart, to: dragCurrent,
                          color: store.currentColor, lineWidth: store.currentLineWidth)
            case .highlight:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                context.fill(Path(preview), with: .color(store.currentColor.opacity(0.4)))
            case .mosaic:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                let path = Path(preview)
                context.fill(path, with: .color(.gray.opacity(0.3)))
                context.stroke(path, with: .color(.gray),
                               style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            case .blur:
                let preview = normalizedRect(from: dragStart, to: dragCurrent)
                let path = Path(preview)
                context.fill(path, with: .color(.blue.opacity(0.15)))
                context.stroke(path, with: .color(.blue),
                               style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            default:
                break
            }
        }

        // Live doodle stroke
        if currentStroke.count > 1 {
            var path = Path()
            path.move(to: currentStroke[0])
            currentStroke.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(path, with: .color(store.currentColor),
                           style: StrokeStyle(lineWidth: store.currentLineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Arrow Drawing Helper

    private func drawArrow(in context: GraphicsContext, from start: CGPoint, to end: CGPoint,
                           color: Color, lineWidth: CGFloat) {
        guard hypot(end.x - start.x, end.y - start.y) > 3 else { return }
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLen = lineWidth * 4 + 10
        let headAngle = CGFloat.pi / 6

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        path.move(to: CGPoint(x: end.x - headLen * cos(angle - headAngle),
                              y: end.y - headLen * sin(angle - headAngle)))
        path.addLine(to: end)
        path.move(to: CGPoint(x: end.x - headLen * cos(angle + headAngle),
                              y: end.y - headLen * sin(angle + headAngle)))
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
                case .rectangle, .mosaic, .blur, .arrow, .highlight:
                    if d > 3 {
                        dragStart = value.startLocation
                        dragCurrent = value.location
                        isDrawingRect = true
                    }
                case .doodle:
                    if currentStroke.isEmpty {
                        currentStroke.append(value.startLocation)
                    }
                    currentStroke.append(value.location)
                case .text, .numberLabel:
                    break
                }
            }
            .onEnded { value in
                let d = hypot(value.translation.width, value.translation.height)
                switch store.currentTool {
                case .rectangle:
                    if d > 5 {
                        store.addRectangle(normalizedRect(from: value.startLocation, to: value.location))
                    }
                    isDrawingRect = false

                case .arrow:
                    if d > 5 {
                        store.addArrow(start: value.startLocation, end: value.location)
                    }
                    isDrawingRect = false

                case .highlight:
                    if d > 5 {
                        store.addHighlight(rect: normalizedRect(from: value.startLocation, to: value.location))
                    }
                    isDrawingRect = false

                case .mosaic:
                    if d > 5 {
                        store.addMosaic(
                            rect: normalizedRect(from: value.startLocation, to: value.location),
                            canvasSize: canvasSize
                        )
                    }
                    isDrawingRect = false

                case .blur:
                    if d > 5 {
                        store.addBlur(
                            rect: normalizedRect(from: value.startLocation, to: value.location),
                            canvasSize: canvasSize
                        )
                    }
                    isDrawingRect = false

                case .doodle:
                    store.addDoodle(points: currentStroke)
                    currentStroke = []

                case .text:
                    if d < 5 {
                        textInputPosition = value.startLocation
                        showTextInput = true
                    }

                case .numberLabel:
                    if d < 5 {
                        store.addNumberLabel(at: value.startLocation)
                    }
                }
            }
    }

    // MARK: - Helpers

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func updateCursor(active: Bool) {
        if active {
            switch store.currentTool {
            case .text: NSCursor.iBeam.set()
            default:    NSCursor.crosshair.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }
}
