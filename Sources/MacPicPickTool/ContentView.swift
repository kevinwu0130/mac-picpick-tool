import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = AnnotationStore()
    @State private var showTextInput = false
    @State private var textInputPosition: CGPoint = .zero
    @State private var textInput = ""
    @State private var canvasSize: CGSize = .zero

    // Keeps the overlay window alive while it's on screen
    @State private var screenshotOverlay: ScreenshotOverlayWindow?

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(store: store, onSave: saveAnnotatedImage, onScreenshot: startScreenshot)
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

    // MARK: - Screenshot

    private func startScreenshot() {
        // Request / verify Screen Recording permission
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            showPermissionAlert()
            return
        }

        // Capture a reference to our window before hiding it
        let appWindow = NSApp.keyWindow ?? NSApp.mainWindow
        appWindow?.orderOut(nil)

        // Let the window disappear before the overlay appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let overlay = ScreenshotOverlayWindow.makeForMainScreen() else {
                appWindow?.makeKeyAndOrderFront(nil)
                return
            }
            screenshotOverlay = overlay
            overlay.start(
                onCapture: { image in
                    screenshotOverlay = nil
                    appWindow?.makeKeyAndOrderFront(nil)
                    store.loadImage(nsImage: image)
                },
                onCancel: {
                    screenshotOverlay = nil
                    appWindow?.makeKeyAndOrderFront(nil)
                }
            )
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「螢幕錄製」權限"
        alert.informativeText = """
            請前往「系統設定 → 隱私權與安全性 → 螢幕錄製」，\
            勾選 MacPicPickTool，然後重新啟動 App。
            """
        alert.addButton(withTitle: "開啟系統設定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            )
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
