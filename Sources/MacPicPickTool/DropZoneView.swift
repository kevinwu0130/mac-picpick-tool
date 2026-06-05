import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var store: AnnotationStore
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            VStack(spacing: 20) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 64))
                    .foregroundColor(isTargeted ? .accentColor : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: isTargeted)

                VStack(spacing: 6) {
                    Text("拖放圖片到此處")
                        .font(.title2.weight(.medium))
                    Text("支援 PNG、JPEG、TIFF、BMP、GIF 格式")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Button("選擇圖片…") { openImageFile() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .padding(20)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            loadDropped(providers)
        }
    }

    private func openImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            store.loadImage(from: url)
        }
    }

    private func loadDropped(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            DispatchQueue.main.async {
                self.store.loadImage(from: url)
            }
        }
        return true
    }
}
