import CoreMedia
import Foundation

enum FrameRate: Int, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) fps"
    }

    var frameInterval: CMTime {
        CMTime(value: 1, timescale: CMTimeScale(rawValue))
    }
}
