import Foundation

enum VideoQuality: String, CaseIterable, Identifiable {
    case standard
    case high
    case losslessLike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            "Standard"
        case .high:
            "Hoch"
        case .losslessLike:
            "Sehr hoch"
        }
    }

    var detail: String {
        switch self {
        case .standard:
            "kleinere Dateien"
        case .high:
            "scharfer Text"
        case .losslessLike:
            "maximale Qualitaet"
        }
    }

    var bitsPerPixel: Int {
        switch self {
        case .standard:
            7
        case .high:
            12
        case .losslessLike:
            18
        }
    }

    var minimumBitrate: Int {
        switch self {
        case .standard:
            10_000_000
        case .high:
            24_000_000
        case .losslessLike:
            48_000_000
        }
    }
}
