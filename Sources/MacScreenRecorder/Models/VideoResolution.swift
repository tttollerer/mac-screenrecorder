import CoreGraphics
import Foundation

enum VideoResolution: String, CaseIterable, Identifiable {
    case native
    case fullHD
    case quadHD
    case ultraHD

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native:
            "Nativ"
        case .fullHD:
            "1080p"
        case .quadHD:
            "1440p"
        case .ultraHD:
            "4K"
        }
    }

    var detail: String {
        switch self {
        case .native:
            "Retina-Quellaufloesung"
        case .fullHD:
            "1920 x 1080"
        case .quadHD:
            "2560 x 1440"
        case .ultraHD:
            "3840 x 2160"
        }
    }

    func outputSize(for sourceSize: CGSize) -> CGSize {
        let cleanSource = CGSize(
            width: max(2, sourceSize.width),
            height: max(2, sourceSize.height)
        )

        guard let targetLongEdge else {
            return cleanSource
        }

        let longEdge = max(cleanSource.width, cleanSource.height)
        guard longEdge > targetLongEdge else {
            return cleanSource
        }

        let scale = targetLongEdge / longEdge
        return CGSize(
            width: cleanSource.width * scale,
            height: cleanSource.height * scale
        )
    }

    private var targetLongEdge: CGFloat? {
        switch self {
        case .native:
            nil
        case .fullHD:
            1920
        case .quadHD:
            2560
        case .ultraHD:
            3840
        }
    }
}
