import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = AnnotationStore()
    @State private var showTextInput = false
    @State private var textInputPosition: CGPoint = .zero
    @State private var textInput = ""
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(store: store, onSave: saveAnnotatedImage)
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
        // Hidden buttons register keyboard shortcuts throughout the window
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
            Button("") { store.currentTool = .rectangle }.keyboardShortcut("r", modifiers: [])
            Button("") { store.currentTool = .text }.keyboardShortcut("t", modifiers: [])
            Button("") { store.currentTool = .doodle }.keyboardShortcut("p", modifiers: [])
            Button("") { store.currentTool = .mosaic }.keyboardShortcut("m", modifiers: [])
            Button("") { store.undo() }.keyboardShortcut("z", modifiers: .command)
            Button("") { saveAnnotatedImage() }.keyboardShortcut("s", modifiers: .command)
        }
        .hidden()
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
