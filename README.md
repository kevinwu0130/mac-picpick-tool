# Mac PicPick Tool

macOS 專用的截圖標註工具，以純 SwiftUI 實作。

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 功能

### 截圖
- **全域快捷鍵** Control+Command+Z — 從任何 App 觸發截圖
- 框選螢幕區域後自動開新視窗並載入
- 截圖自動儲存至 `~/Pictures/MacPicPickTool/`
- 可選「截後複製」— 截圖同時自動放入剪貼簿

### 標註工具

| 工具 | 快捷鍵 | 說明 |
|------|--------|------|
| 選取 | `V` | 點擊標註後拖曳移動 |
| 矩形框 | `R` | 拖曳畫矩形邊框 |
| 箭頭 | `A` | 拖曳畫帶箭頭的線段 |
| 直線 | `L` | 拖曳畫直線 |
| 橢圓 | `E` | 拖曳畫橢圓 |
| 文字 | `T` | 點擊後輸入文字，可調整大小 |
| 塗鴉 | `P` | 自由手繪 |
| 螢光筆 | `H` | 半透明色塊標記重點 |
| 馬賽克 | `M` | 像素化遮蔽敏感資訊 |
| 模糊 | `B` | 高斯模糊遮蔽區域 |
| 流水號 | `N` | 紅圈數字標記步驟 |

### 屬性控制
- **顏色選擇** — 所有工具共用，支援任意顏色
- **線條粗細** — 1–8 pt 滑桿調整
- **文字大小** — 10–48 pt 滑桿調整（文字工具限定）

### 編輯
- **復原** ⌘Z — 逐步撤銷標註
- **清除** — 移除所有標註

### 匯出 / 分享
- **複製到剪貼簿** ⌘C — 含標註的圖片直接貼到任何 App
- **儲存為 PNG** ⌘S — 全解析度輸出
- **⌘V 貼上** — 從剪貼簿貼入圖片

### 多視窗 & 截圖歷史
- 每次截圖開啟獨立視窗，各自維護標註狀態
- 左側截圖歷史面板，顯示縮圖與時間，點擊即載入
- 工具列「截圖資料夾」按鈕直接在 Finder 開啟儲存路徑

## 系統需求

| 項目 | 版本 |
|------|------|
| macOS | 13 Ventura 或更新版本 |
| Swift | 5.9 或更新版本 |

## 建置與執行

```bash
git clone https://github.com/kevinwu0130/mac-picpick-tool.git
cd mac-picpick-tool
swift run
```

或在 Xcode 中開啟 `Package.swift`，選擇 `MacPicPickTool` scheme 後按 ⌘R。

首次執行需至「系統設定 → 隱私權與安全性 → 螢幕錄製」授權 App。

## 專案結構

```
Sources/MacPicPickTool/
├── App.swift                  # @main 入口點
├── AppDelegate.swift          # 全域快捷鍵初始化
├── GlobalHotkey.swift         # Control+Command+Z 系統快捷鍵（Carbon API）
├── WindowManager.swift        # 多視窗管理、截圖流程、自動儲存
├── AnnotationModels.swift     # 資料模型與列舉
├── AnnotationStore.swift      # 狀態管理、匯出、剪貼簿
├── AnnotationWindowContent.swift  # 單一視窗根視圖
├── AnnotationCanvas.swift     # 畫布繪圖與手勢處理
├── ToolbarView.swift          # 工具列（兩排）
├── HistorySidebarView.swift   # 截圖歷史側邊欄
├── DropZoneView.swift         # 拖放提示畫面
├── ScreenshotOverlay.swift    # 截圖選取覆蓋層
└── TextInputSheet.swift       # 文字標註輸入 Sheet
```

## 授權

MIT License
