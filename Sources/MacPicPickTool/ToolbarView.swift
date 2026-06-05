import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToolbarView: View {
    @ObservedObject var store: AnnotationStore
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { openImageFile() } label: {
                Label("開啟圖片", systemImage: "photo")
            }
            .help("開啟圖片檔案")

            Divider().frame(height: 22)

            // Tool buttons — each shows icon + label + shortcut key badge
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                toolButton(for: tool)
            }

            Divider().frame(height: 22)

            Button { store.undo() } label: {
                Label("復原", systemImage: "arrow.uturn.backward")
            }
            .disabled(!store.hasAnnotations)
            .help("復原最後一個標註 (⌘Z)")

            Button { store.clearAnnotations() } label: {
                Image(systemName: "trash")
            }
            .disabled(!store.hasAnnotations)
            .help("清除所有標註")

            Spacer()

            if store.selectedImage != nil {
                Button(action: onSave) {
                    Label("儲存圖片", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .help("將標註後的圖片儲存為 PNG (⌘S)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func toolButton(for tool: AnnotationTool) -> some View {
        let selected = store.currentTool == tool
        Button { store.currentTool = tool } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 15))
                HStack(spacing: 3) {
                    Text(tool.label)
                        .font(.caption2)
                    Text("[\(tool.shortcutKey)]")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 64)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .background(selected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .help("\(tool.label) — 按 \(tool.shortcutKey) 切換")
    }

    private func openImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif]
        panel.allowsMultipleSelection = false
        panel.message = "選擇要標註的圖片"
        panel.prompt = "開啟"

        if panel.runModal() == .OK, let url = panel.url {
            store.loadImage(from: url)
        }
    }
}
