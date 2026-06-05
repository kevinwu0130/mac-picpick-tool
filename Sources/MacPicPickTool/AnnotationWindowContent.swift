import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The view hierarchy for a single annotation window.
/// Each window gets its own independent AnnotationStore via @StateObject.
struct AnnotationWindowContent: View {
    @StateObject private var store: AnnotationStore
    @State private var showTextInput = false
    @State private var textInputPosition: CGPoint = .zero
    @State private var textInput = ""
    @State private var canvasSize: CGSize = .zero

    init(initialImage: NSImage? = nil) {
        let s = AnnotationStore()
        if let image = initialImage {
            s.loadImage(nsImage: image)
        }
        _store = StateObject(wrappedValue: s)
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(
                store: store,
                onSave: saveAnnotatedImage,
                onScreenshot: { WindowManager.shared.startScreenshot() },
                onCopy: copyToClipboard
            )
            Divider()
            HStack(spacing: 0) {
                HistorySidebarView(store: store)
                Divider()
                Group {
                    if store.selectedImage != nil {
                        AnnotationCanvas(
                            store: store,
                            showTextInput: $showTextInput,
                            textInputPosition: $textInputPosition,
                            canvasSize: $canvasSize
                        )
                    } else {
                        DropZoneView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(keyboardShortcuts)
        .sheet(isPresented: $showTextInput) {
            TextInputSheet(text: $textInput) { confirmed in
                let trimmed = textInput.trimmingCharacters(in: .whitespaces)
                if confirmed, !trimmed.isEmpty {
                    store.addText(trimmed, at: textInputPosition)
                }
                textInput = ""
                showTextInput = false
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcuts: some View {
        Group {
            Button("") { store.currentTool = .select }.keyboardShortcut("v", modifiers: [])
            Button("") { store.currentTool = .rectangle }.keyboardShortcut("r", modifiers: [])
            Button("") { store.currentTool = .arrow }.keyboardShortcut("a", modifiers: [])
            Button("") { store.currentTool = .line }.keyboardShortcut("l", modifiers: [])
            Button("") { store.currentTool = .ellipse }.keyboardShortcut("e", modifiers: [])
            Button("") { store.currentTool = .text }.keyboardShortcut("t", modifiers: [])
            Button("") { store.currentTool = .doodle }.keyboardShortcut("p", modifiers: [])
            Button("") { store.currentTool = .highlight }.keyboardShortcut("h", modifiers: [])
            Button("") { store.currentTool = .mosaic }.keyboardShortcut("m", modifiers: [])
            Button("") { store.currentTool = .blur }.keyboardShortcut("b", modifiers: [])
            Button("") { store.currentTool = .numberLabel }.keyboardShortcut("n", modifiers: [])
            Button("") { store.undo() }.keyboardShortcut("z", modifiers: .command)
            Button("") { saveAnnotatedImage() }.keyboardShortcut("s", modifiers: .command)
            Button("") { copyToClipboard() }.keyboardShortcut("c", modifiers: .command)
            Button("") { pasteFromClipboard() }.keyboardShortcut("v", modifiers: .command)
        }
        .hidden()
    }

    // MARK: - Paste from Clipboard

    private func pasteFromClipboard() {
        guard let image = NSImage(pasteboard: .general) else { return }
        store.loadImage(nsImage: image)
    }

    // MARK: - Copy to Clipboard

    private func copyToClipboard() {
        store.copyToClipboard(canvasSize: canvasSize)
    }

    // MARK: - Export

    private func saveAnnotatedImage() {
        guard let exported = store.exportAnnotatedImage(canvasSize: canvasSize) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "annotated.png"
        panel.canCreateDirectories = true
        panel.message = "儲存標註後的圖片"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let cgImg = exported.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cgImg)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }
}
