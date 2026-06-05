import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToolbarView: View {
    @ObservedObject var store: AnnotationStore
    let onSave: () -> Void
    let onScreenshot: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Actions + colour/width properties + undo/clear + copy/save
            HStack(spacing: 8) {
                Button { onScreenshot() } label: {
                    Label("截圖", systemImage: "camera.viewfinder")
                }
                .help("螢幕截圖 (Control+Command+Z)")

                Button { openImageFile() } label: {
                    Label("開啟", systemImage: "photo")
                }
                .help("開啟圖片")

                Divider().frame(height: 20)

                ColorPicker("", selection: $store.currentColor)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
                    .help("標註顏色")

                HStack(spacing: 4) {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Slider(value: $store.currentLineWidth, in: 1...8, step: 1)
                        .frame(width: 72)
                    Text("\(Int(store.currentLineWidth))pt")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 26, alignment: .leading)
                }
                .help("線條粗細")

                Divider().frame(height: 20)

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
                    Button(action: onCopy) {
                        Label("複製", systemImage: "doc.on.clipboard")
                    }
                    .help("複製到剪貼簿 (⌘C)")

                    Button(action: onSave) {
                        Label("儲存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("儲存為 PNG (⌘S)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            Divider()

            // Row 2: Tool selection
            HStack(spacing: 4) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    toolButton(for: tool)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func toolButton(for tool: AnnotationTool) -> some View {
        let selected = store.currentTool == tool
        let badge: String = tool == .numberLabel
            ? "[\(store.nextLabelNumber)]"
            : "[\(tool.shortcutKey)]"
        Button { store.currentTool = tool } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 14))
                HStack(spacing: 2) {
                    Text(tool.label)
                        .font(.caption2)
                    Text(badge)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 56)
            .padding(.vertical, 4)
            .padding(.horizontal, 5)
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
