import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        hotkey = GlobalHotkey()
        WindowManager.shared.createNewWindow()
    }

    // Termination is handled by WindowManager when the last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
