import SwiftUI

@main
struct MacPicPickToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
