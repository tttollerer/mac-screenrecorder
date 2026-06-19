import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case display
    case window
    case region

    var id: String { rawValue }

    var title: String {
        switch self {
        case .display: "Bildschirm"
        case .window: "Fenster"
        case .region: "Bereich"
        }
    }

    var systemImage: String {
        switch self {
        case .display: "display"
        case .window: "macwindow"
        case .region: "crop"
        }
    }
}
