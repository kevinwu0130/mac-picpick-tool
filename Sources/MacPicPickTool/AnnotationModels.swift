import Foundation
import CoreGraphics

struct RectAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
}

struct TextAnnotation: Identifiable {
    let id = UUID()
    let position: CGPoint
    let text: String
}

enum AnnotationTool: CaseIterable, Hashable {
    case rectangle
    case text

    var label: String {
        switch self {
        case .rectangle: return "矩形框"
        case .text: return "文字標註"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: return "rectangle"
        case .text: return "text.cursor"
        }
    }
}
