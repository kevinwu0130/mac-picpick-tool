import Foundation
import CoreGraphics
import AppKit

struct RectAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
}

struct TextAnnotation: Identifiable {
    let id = UUID()
    let position: CGPoint
    let text: String
}

struct DoodleAnnotation: Identifiable {
    let id = UUID()
    let points: [CGPoint]
}

struct MosaicAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect    // canvas-space rect
    let tile: NSImage   // precomputed pixelated tile at canvas display size
}

struct BlurAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect    // canvas-space rect
    let tile: NSImage   // precomputed Gaussian-blurred tile at canvas display size
}

struct NumberLabelAnnotation: Identifiable {
    let id = UUID()
    let position: CGPoint
    let number: Int
}

// Tracks which kind was last added, for ordered undo.
enum AnnotationKind {
    case rectangle, text, doodle, mosaic, blur, numberLabel
}

enum AnnotationTool: CaseIterable, Hashable {
    case rectangle
    case text
    case doodle
    case mosaic
    case blur
    case numberLabel

    var label: String {
        switch self {
        case .rectangle:   return "矩形框"
        case .text:        return "文字標註"
        case .doodle:      return "自由塗鴉"
        case .mosaic:      return "馬賽克"
        case .blur:        return "模糊"
        case .numberLabel: return "流水號"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle:   return "rectangle"
        case .text:        return "text.cursor"
        case .doodle:      return "scribble"
        case .mosaic:      return "square.grid.2x2"
        case .blur:        return "camera.filters"
        case .numberLabel: return "number.circle"
        }
    }

    var shortcutKey: String {
        switch self {
        case .rectangle:   return "R"
        case .text:        return "T"
        case .doodle:      return "P"
        case .mosaic:      return "M"
        case .blur:        return "B"
        case .numberLabel: return "N"
        }
    }
}
