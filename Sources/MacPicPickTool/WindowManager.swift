import AppKit
import SwiftUI
import CoreGraphics

final class WindowManager {
    static let shared = WindowManager()

    private var windows: [UUID: NSWindow] = [:]
    private var screenshotOverlay: ScreenshotOverlayWindow?

    var windowCount: Int { windows.count }

    // MARK: - Window Creation

    func createNewWindow(image: NSImage? = nil) {
        let id = UUID()
        let content = AnnotationWindowContent(initialImage: image)
        let hosting = NSHostingView(rootView: content)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.title = image != nil ? "截圖標註" : "Mac PicPick Tool"
        window.minSize = NSSize(width: 700, height: 500)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windows[id] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.windows.removeValue(forKey: id)
            if self?.windows.isEmpty == true {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Screenshot Flow

    func startScreenshot() {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            showPermissionAlert()
            return
        }

        // Hide all visible app windows so the screen is clean for capture
        let visibleWindows = windows.values.filter { $0.isVisible }
        visibleWindows.forEach { $0.orderOut(nil) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let overlay = ScreenshotOverlayWindow.makeForMainScreen() else {
                visibleWindows.forEach { $0.makeKeyAndOrderFront(nil) }
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            self?.screenshotOverlay = overlay
            overlay.start(
                onCapture: { [weak self] image in
                    self?.screenshotOverlay = nil
                    visibleWindows.forEach { $0.makeKeyAndOrderFront(nil) }
                    NSApp.activate(ignoringOtherApps: true)
                    self?.autoSave(image)
                    self?.createNewWindow(image: image)
                },
                onCancel: { [weak self] in
                    self?.screenshotOverlay = nil
                    visibleWindows.forEach { $0.makeKeyAndOrderFront(nil) }
                    NSApp.activate(ignoringOtherApps: true)
                }
            )
        }
    }

    // MARK: - Auto Save

    private func autoSave(_ image: NSImage) {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/MacPicPickTool")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd_HHmm"
        let filename = "Screenshot_\(fmt.string(from: Date())).png"
        let url = dir.appendingPathComponent(filename)

        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }

    // MARK: - Permission Alert

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
}
