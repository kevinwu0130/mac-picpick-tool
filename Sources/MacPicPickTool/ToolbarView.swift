import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToolbarView: View {
    @ObservedObject var store: AnnotationStore
    let onSave: () -> Void
    let onScreenshot: () -> Void
    let onCopy: () -> Void

    @AppStorage("autoCopyAfterScreenshot") private var autoCopyAfterScreenshot = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Actions + Properties + Auto-copy + Undo/Clear + Copy/Save
            HStack(spacing: 8) {
                Button { onScreenshot() } label: { Label("截圖", systemImage: "camera.viewfinder") }
                    .help("螢幕截圖 (Control+Command+Z)")

                Button { openImageFile() } label: { Label("開啟", systemImage: "photo") }
                    .help("開啟圖片")

                Button { openSaveFolder() } label: { Label("截圖資料夾", systemImage: "folder") }
                    .help("在 Finder 中開啟截圖資料夾")

                Divider().frame(height: 20)

                // Colour
                ColorPicker("", selection: $store.currentColor)
                    .labelsHidden().frame(width: 28, height: 28).help("標註顏色")

                // Line width
                HStack(spacing: 3) {
                    Image(systemName: "line.diagonal").font(.system(size: 9)).foregroundColor(.secondary)
                    Slider(value: $store.currentLineWidth, in: 1...8, step: 1).frame(width: 60)
                    Text("\(Int(store.currentLineWidth))pt").font(.caption2).foregroundColor(.secondary)
                        .frame(width: 24, alignment: .leading)
                }.help("線條粗細")

                // Font size (greyed out when not text tool)
                HStack(spacing: 3) {
                    Image(systemName: "textformat.size").font(.system(size: 9)).foregroundColor(.secondary)
                    Slider(value: $store.currentFontSize, in: 10...48, step: 2).frame(width: 55)
                    Text("\(Int(store.currentFontSize))pt").font(.caption2).foregroundColor(.secondary)
                        .frame(width: 24, alignment: .leading)
                }
                .help("文字大小（文字工具）")
                .opacity(store.currentTool == .text ? 1.0 : 0.35)
                .disabled(store.currentTool != .text)

                Divider().frame(height: 20)

                // Auto-copy toggle
                Toggle(isOn: $autoCopyAfterScreenshot) {
                    Label("截後複製", systemImage: "doc.on.clipboard")
                }
                .toggleStyle(.checkbox)
                .font(.caption2)
                .help("截圖後自動複製到剪貼簿")

                Divider().frame(height: 20)

                Button { store.undo() } label: { Label("復原", systemImage: "arrow.uturn.backward") }
                    .disabled(!store.hasAnnotations).help("復原 (⌘Z)")
                Button { store.clearAnnotations() } label: { Image(systemName: "trash") }
                    .disabled(!store.hasAnnotations).help("清除所有")

                Spacer()

                if store.selectedImage != nil {
                    Button(action: onCopy) { Label("複製", systemImage: "doc.on.clipboard") }
                        .help("複製到剪貼簿 (⌘C)")
                    Button(action: onSave) { Label("儲存", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.borderedProminent).help("儲存為 PNG (⌘S)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            Divider()

            // Row 2: Tool selection
            HStack(spacing: 3) {
                ForEach(AnnotationTool.allCases, id: \.self) { tool in
                    toolButton(for: tool)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func toolButton(for tool: AnnotationTool) -> some View {
        let selected = store.currentTool == tool
        let badge = tool == .numberLabel ? "[\(store.nextLabelNumber)]" : "[\(tool.shortcutKey)]"
        Button { store.currentTool = tool } label: {
            VStack(spacing: 2) {
                Image(systemName: tool.systemImage).font(.system(size: 13))
                HStack(spacing: 2) {
                    Text(tool.label).font(.caption2)
                    Text(badge).font(.caption2).foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 52)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .background(selected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1))
        .help("\(tool.label) — 按 \(tool.shortcutKey) 切換")
    }

    private func openSaveFolder() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/MacPicPickTool")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    private func openImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif]
        panel.allowsMultipleSelection = false
        panel.message = "選擇要標註的圖片"
        panel.prompt = "開啟"
        if panel.runModal() == .OK, let url = panel.url { store.loadImage(from: url) }
    }
}
