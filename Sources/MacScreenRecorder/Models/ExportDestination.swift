import Foundation

enum ExportDestination: String, CaseIterable, Identifiable {
    case youtube
    case linkedin
    case website
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youtube:
            "YouTube"
        case .linkedin:
            "LinkedIn"
        case .website:
            "Website"
        case .archive:
            "Archiv"
        }
    }

    var detail: String {
        switch self {
        case .youtube:
            "scharf, 60 fps moeglich"
        case .linkedin:
            "kompatibel und moderat gross"
        case .website:
            "gute Qualitaet bei kleiner Datei"
        case .archive:
            "maximale Qualitaet"
        }
    }
}
