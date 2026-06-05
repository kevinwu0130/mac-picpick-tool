import SwiftUI
import AppKit

struct AnnotationCanvas: View {
    @ObservedObject var store: AnnotationStore
    @Binding var showTextInput: Bool
    @Binding var textInputPosition: CGPoint
    @Binding var canvasSize: CGSize

    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var isDrawingRect = false
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

    private var canvasOverlay: some View {
        GeometryReader { geo in
            Canvas { context, _ in
                drawAnnotations(in: context)
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

    // MARK: - Drawing

    private func drawAnnotations(in context: GraphicsContext) {
        for rect in store.rectangles {
            let path = Path(rect.rect)
            context.stroke(path, with: .color(.red), lineWidth: 2)
        }

        if isDrawingRect {
            let previewRect = normalizedRect(from: dragStart, to: dragCurrent)
            let path = Path(previewRect)
            context.fill(path, with: .color(.red.opacity(0.1)))
            context.stroke(path, with: .color(.red), lineWidth: 2)
        }

        for annotation in store.textAnnotations {
            let label = Text(annotation.text)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.red)
            // draw() centers the text at the given point
            context.draw(label, at: annotation.position)
        }
    }

    // MARK: - Gesture

    private var interactionGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard store.currentTool == .rectangle else { return }
                let d = hypot(value.translation.width, value.translation.height)
                if d > 3 {
                    dragStart = value.startLocation
                    dragCurrent = value.location
                    isDrawingRect = true
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
            case .rectangle: NSCursor.crosshair.set()
            case .text: NSCursor.iBeam.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }
}
