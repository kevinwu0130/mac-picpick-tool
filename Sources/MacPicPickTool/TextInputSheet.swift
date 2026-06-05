import SwiftUI

struct TextInputSheet: View {
    @Binding var text: String
    let onDismiss: (Bool) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("新增文字標註")
                .font(.headline)

            TextField("輸入標註文字…", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .focused($isFocused)
                .onSubmit { onDismiss(true) }

            HStack(spacing: 12) {
                Button("取消") { onDismiss(false) }
                    .keyboardShortcut(.escape, modifiers: [])

                Button("加入標註") { onDismiss(true) }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 340, height: 140)
        .onAppear { isFocused = true }
    }
}
