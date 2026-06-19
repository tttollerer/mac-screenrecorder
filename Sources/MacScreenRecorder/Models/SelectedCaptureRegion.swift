import CoreGraphics
import Foundation

struct SelectedCaptureRegion: Equatable {
    let displayID: CGDirectDisplayID
    let sourceRect: CGRect

    var sizeLabel: String {
        "\(Int(sourceRect.width))x\(Int(sourceRect.height))"
    }
}
