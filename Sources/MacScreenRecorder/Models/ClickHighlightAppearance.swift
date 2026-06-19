import AppKit
import Foundation

enum ClickHighlightColor: String, CaseIterable, Identifiable {
    case blue
    case yellow
    case red
    case green

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue:
            "Blau"
        case .yellow:
            "Gelb"
        case .red:
            "Rot"
        case .green:
            "Gruen"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .blue:
            .systemBlue
        case .yellow:
            .systemYellow
        case .red:
            .systemRed
        case .green:
            .systemGreen
        }
    }
}

enum ClickHighlightSize: String, CaseIterable, Identifiable {
    case compact
    case normal
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            "Kompakt"
        case .normal:
            "Normal"
        case .large:
            "Gross"
        }
    }

    var scale: Double {
        switch self {
        case .compact:
            0.78
        case .normal:
            1
        case .large:
            1.32
        }
    }
}

struct ClickHighlightConfiguration {
    let color: ClickHighlightColor
    let size: ClickHighlightSize
}
