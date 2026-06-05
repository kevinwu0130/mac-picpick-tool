import SwiftUI
import AppKit

struct AnnotationCanvas: View {
    @ObservedObject var store: AnnotationStore
    @Binding var showTextInput: Bool
    @Binding var textInputPosition: CGPoint
    @Binding var canvasSize: CGSize

    // Shared drag state (used by rectangle and mosaic tools)
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var isDrawingRect = false

    // Doodle-specific state
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
        // Committed rectangles
        for rect in store.rectangles {
            context.stroke(Path(rect.rect), with: .color(.red), lineWidth: 2)
        }

        // Committed doodles
        for doodle in store.doodles {
            guard doodle.points.count > 1 else { continue }
            var path = Path()
            path.move(to: doodle.points[0])
            doodle.points.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(path, with: .color(.red),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }

        // Committed mosaics — draw the precomputed pixelated tile
        for mosaic in store.mosaics {
            context.draw(Image(nsImage: mosaic.tile), in: mosaic.rect)
        }

        // Committed text annotations
        for annotation in store.textAnnotations {
            context.draw(
                Text(annotation.text).font(.system(size: 16, weight: .bold)).foregroundColor(.red),
                at: annotation.position
            )
        }

        // Live preview: rectangle or mosaic drag
        if isDrawingRect {
            let preview = normalizedRect(from: dragStart, to: dragCurrent)
            let path = Path(preview)
            if store.currentTool == .rectangle {
                context.fill(path, with: .color(.red.opacity(0.1)))
                context.stroke(path, with: .color(.red), lineWidth: 2)
            } else {
                // Mosaic preview: dashed gray box
                context.fill(path, with: .color(.gray.opacity(0.3)))
                context.stroke(path, with: .color(.gray),
                               style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            }
        }

        // Live preview: current doodle stroke
        if currentStroke.count > 1 {
            var path = Path()
            path.move(to: currentStroke[0])
            currentStroke.dropFirst().forEach { path.addLine(to: $0) }
            context.stroke(path, with: .color(.red),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Gesture

    private var interactionGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let d = hypot(value.translation.width, value.translation.height)
                switch store.currentTool {
                case .rectangle, .mosaic:
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
                case .text:
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

                case .mosaic:
                    if d > 5 {
                        store.addMosaic(
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
            case .rectangle, .doodle, .mosaic: NSCursor.crosshair.set()
            case .text: NSCursor.iBeam.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }
}
