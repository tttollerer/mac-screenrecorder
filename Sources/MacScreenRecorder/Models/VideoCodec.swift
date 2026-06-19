import AVFoundation
import Foundation

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264
    case hevc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .h264:
            "H.264"
        case .hevc:
            "HEVC"
        }
    }

    var detail: String {
        switch self {
        case .h264:
            "maximale Kompatibilitaet"
        case .hevc:
            "kleinere Dateien bei hoher Qualitaet"
        }
    }

    var avCodec: AVVideoCodecType {
        switch self {
        case .h264:
            .h264
        case .hevc:
            .hevc
        }
    }
}
