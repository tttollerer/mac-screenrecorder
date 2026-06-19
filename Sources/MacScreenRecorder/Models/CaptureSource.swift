import CoreGraphics
import Foundation

enum CaptureSourceKind: String {
    case display
    case window
}

struct CaptureSource: Identifiable, Hashable {
    let id: String
    let kind: CaptureSourceKind
    let title: String
    let subtitle: String
    let displayID: CGDirectDisplayID?
    let windowID: UInt32?
    let width: Int
    let height: Int

    var sizeLabel: String {
        "\(width)x\(height)"
    }
}
