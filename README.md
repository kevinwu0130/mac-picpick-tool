# Mac PicPick Tool

macOS 專用的圖片編輯標註工具，類似 PicPick，以純 SwiftUI 實作。

## 功能

- 載入圖片（PNG / JPEG / TIFF / BMP / GIF，支援拖放或對話框選取）
- 用滑鼠拖曳在圖片上畫出**紅色矩形框**
- 點擊任意位置新增**文字標註**（紅色粗體 + 半透明黑色背景）
- 復原（Undo）最後一個標註
- 清除所有標註
- 將標註後的圖片以全解析度匯出為 **PNG**

## 系統需求

| 項目 | 版本 |
|------|------|
| macOS | 13 Ventura 或更新版本 |
| Swift | 5.9 或更新版本（Swift 6 編譯器亦相容） |

## 建置與執行

```bash
git clone https://github.com/<你的帳號>/mac-picpick-tool.git
cd mac-picpick-tool
swift run
```

或在 Xcode 中開啟 `Package.swift`，選擇 `MacPicPickTool` scheme 後按 ⌘R。

## 操作說明

1. **載入圖片**：拖放圖片到視窗，或點擊「選擇圖片」按鈕，也可使用工具列「開啟圖片」。
2. **矩形框**：在工具列選取「矩形框」，在圖片上按住滑鼠拖曳即可繪製紅色矩形。
3. **文字標註**：在工具列選取「文字標註」，點擊圖片任一位置後輸入文字，按 Enter 或「加入標註」確認。
4. **復原 / 清除**：工具列提供「復原」（移除最後一個標註）與「清除」（移除全部）按鈕。
5. **儲存**：點擊工具列右側「儲存圖片」按鈕，選擇路徑後存為 PNG。

## 專案結構

```
Sources/MacPicPickTool/
├── App.swift              # @main 入口點
├── AnnotationModels.swift # 資料模型（RectAnnotation、TextAnnotation、AnnotationTool）
├── AnnotationStore.swift  # ObservableObject 狀態管理與圖片匯出
├── ContentView.swift      # 根視圖，協調各子視圖
├── AnnotationCanvas.swift # 圖片顯示與手勢處理（Canvas 繪圖層）
├── ToolbarView.swift      # 上方工具列
├── DropZoneView.swift     # 初始拖放提示畫面
└── TextInputSheet.swift   # 文字標註輸入 Sheet
```

## 授權

MIT License
