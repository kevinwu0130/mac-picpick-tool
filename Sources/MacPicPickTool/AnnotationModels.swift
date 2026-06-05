import Foundation
import CoreGraphics
import AppKit
import SwiftUI

struct RectAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let color: Color
    let lineWidth: CGFloat
}

struct TextAnnotation: Identifiable {
    let id = UUID()
    let position: CGPoint
    let text: String
    let color: Color
}

struct DoodleAnnotation: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}

struct ArrowAnnotation: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
}

struct MosaicAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let tile: NSImage
}

struct BlurAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let tile: NSImage
}

struct NumberLabelAnnotation: Identifiable {
    let id = UUID()
    let position: CGPoint
    let number: Int
    let color: Color
}

struct HighlightAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let color: Color
}

enum AnnotationKind {
    case rectangle, text, doodle, mosaic, blur, numberLabel, arrow, highlight
}

enum AnnotationTool: CaseIterable, Hashable {
    case rectangle
    case arrow
    case text
    case doodle
    case highlight
    case mosaic
    case blur
    case numberLabel

    var label: String {
        switch self {
        case .rectangle:   return "矩形框"
        case .arrow:       return "箭頭"
        case .text:        return "文字"
        case .doodle:      return "塗鴉"
        case .highlight:   return "螢光筆"
        case .mosaic:      return "馬賽克"
        case .blur:        return "模糊"
        case .numberLabel: return "流水號"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle:   return "rectangle"
        case .arrow:       return "arrow.up.right"
        case .text:        return "text.cursor"
        case .doodle:      return "scribble"
        case .highlight:   return "highlighter"
        case .mosaic:      return "square.grid.2x2"
        case .blur:        return "camera.filters"
        case .numberLabel: return "number.circle"
        }
    }

    var shortcutKey: String {
        switch self {
        case .rectangle:   return "R"
        case .arrow:       return "A"
        case .text:        return "T"
        case .doodle:      return "P"
        case .highlight:   return "H"
        case .mosaic:      return "M"
        case .blur:        return "B"
        case .numberLabel: return "N"
        }
    }
}
