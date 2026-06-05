import Foundation
import CoreGraphics
import AppKit
import SwiftUI

// MARK: - CGPoint helper

extension CGPoint {
    func offset(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}

// MARK: - Annotation Structs

struct RectAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let color: Color
    let lineWidth: CGFloat
    let filled: Bool
}

struct TextAnnotation: Identifiable {
    let id = UUID()
    let position: CGPoint
    let text: String
    let color: Color
    let fontSize: CGFloat
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

struct LineAnnotation: Identifiable {
    let id = UUID()
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
}

struct EllipseAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let color: Color
    let lineWidth: CGFloat
    let filled: Bool
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

// MARK: - Enums

enum AnnotationKind {
    case rectangle, text, doodle, mosaic, blur, numberLabel, arrow, highlight, line, ellipse
}

enum AnnotationTool: CaseIterable, Hashable {
    case select
    case rectangle
    case arrow
    case line
    case ellipse
    case text
    case doodle
    case highlight
    case mosaic
    case blur
    case numberLabel

    var label: String {
        switch self {
        case .select:      return "選取"
        case .rectangle:   return "矩形框"
        case .arrow:       return "箭頭"
        case .line:        return "直線"
        case .ellipse:     return "橢圓"
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
        case .select:      return "cursorarrow"
        case .rectangle:   return "rectangle"
        case .arrow:       return "arrow.up.right"
        case .line:        return "line.diagonal"
        case .ellipse:     return "oval"
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
        case .select:      return "V"
        case .rectangle:   return "R"
        case .arrow:       return "A"
        case .line:        return "L"
        case .ellipse:     return "E"
        case .text:        return "T"
        case .doodle:      return "P"
        case .highlight:   return "H"
        case .mosaic:      return "M"
        case .blur:        return "B"
        case .numberLabel: return "N"
        }
    }
}
