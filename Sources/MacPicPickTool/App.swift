import SwiftUI

@main
struct MacPicPickToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Window lifecycle is managed by WindowManager + AppDelegate.
        // Settings is a required placeholder — SwiftUI needs at least one Scene.
        Settings { EmptyView() }
    }
}
