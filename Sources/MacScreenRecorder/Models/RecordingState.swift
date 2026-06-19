import Foundation

enum RecordingState: Equatable {
    case idle
    case preparing
    case countdown(Int)
    case recording(startedAt: Date)
    case paused
    case stopping
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .preparing, .countdown, .recording, .paused, .stopping:
            true
        case .idle, .failed:
            false
        }
    }
}
