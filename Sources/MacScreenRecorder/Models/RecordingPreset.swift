import Foundation

enum RecordingPreset: String, CaseIterable, Identifiable {
    case webDemo1080p
    case retinaSharp
    case socialClip
    case browserWindow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .webDemo1080p:
            "Web Demo 1080p"
        case .retinaSharp:
            "Retina scharf"
        case .socialClip:
            "Social Clip 9:16"
        case .browserWindow:
            "Browser-Fenster"
        }
    }

    var detail: String {
        switch self {
        case .webDemo1080p:
            "klein, kompatibel, 30 fps"
        case .retinaSharp:
            "native Aufloesung, hohe Bitrate"
        case .socialClip:
            "fuer kurze vertikale Clips"
        case .browserWindow:
            "Fensteraufnahme mit scharfem Text"
        }
    }
}
