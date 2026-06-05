import SwiftUI
import AppKit

extension Notification.Name {
    static let newScreenshotSaved = Notification.Name("newScreenshotSaved")
}

struct HistorySidebarView: View {
    @ObservedObject var store: AnnotationStore
    @State private var files: [URL] = []

    static let saveDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/MacPicPickTool")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("截圖歷史")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Button { refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("重新整理")

                Button { openFolder() } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("在 Finder 中開啟")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if files.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("尚無截圖")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(files, id: \.self) { url in
                            HistoryItemView(url: url) {
                                store.loadImage(from: url)
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 155)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .newScreenshotSaved)) { _ in
            refresh()
        }
    }

    private func refresh() {
        let dir = Self.saveDir
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            files = []
            return
        }
        files = urls
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
    }

    private func openFolder() {
        let dir = Self.saveDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }
}

struct HistoryItemView: View {
    let url: URL
    let onSelect: () -> Void
    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Group {
                    if let thumb = thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                ProgressView().scaleEffect(0.6)
                            )
                    }
                }
                .frame(height: 76)
                .cornerRadius(4)

                Text(displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(5)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onAppear { loadThumbnail() }
    }

    private var displayName: String {
        let name = url.deletingPathExtension().lastPathComponent
        // "Screenshot_20260605_1631" -> "06/05 16:31"
        if name.hasPrefix("Screenshot_"), name.count >= 22 {
            let s = name.dropFirst("Screenshot_".count)
            let parts = s.components(separatedBy: "_")
            if parts.count == 2, parts[0].count == 8, parts[1].count == 4 {
                let d = parts[0]
                let t = parts[1]
                let mm = d.dropFirst(4).prefix(2)
                let dd = d.dropFirst(6).prefix(2)
                let hh = t.prefix(2)
                let min = t.dropFirst(2).prefix(2)
                return "\(mm)/\(dd) \(hh):\(min)"
            }
        }
        return name
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            guard let img = NSImage(contentsOf: url) else { return }
            let maxW: CGFloat = 143
            let maxH: CGFloat = 76
            let scale = min(maxW / img.size.width, maxH / img.size.height)
            let size = NSSize(width: img.size.width * scale, height: img.size.height * scale)
            let thumb = NSImage(size: size)
            thumb.lockFocus()
            img.draw(in: NSRect(origin: .zero, size: size),
                     from: NSRect(origin: .zero, size: img.size),
                     operation: .copy, fraction: 1.0)
            thumb.unlockFocus()
            DispatchQueue.main.async { thumbnail = thumb }
        }
    }
}
