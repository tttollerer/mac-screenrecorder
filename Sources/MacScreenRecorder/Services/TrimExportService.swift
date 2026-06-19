@preconcurrency import AVFoundation
import Foundation

private final class UncheckedExportBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

enum TrimExportService {
    static func exportTrimmedCopy(
        sourceURL: URL,
        startSeconds: Double,
        endSeconds: Double
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = max(0, duration.seconds)
        let clampedStart = max(0, min(startSeconds, totalSeconds))
        let clampedEnd = max(clampedStart + 0.2, min(endSeconds, totalSeconds))

        let start = CMTime(seconds: clampedStart, preferredTimescale: 600)
        let end = CMTime(seconds: clampedEnd, preferredTimescale: 600)
        let range = CMTimeRange(start: start, end: end)

        let outputURL = makeOutputURL(for: sourceURL)
        try? FileManager.default.removeItem(at: outputURL)

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw TrimExportError.exportUnavailable
        }

        export.timeRange = range
        export.outputURL = outputURL
        export.outputFileType = export.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
        export.shouldOptimizeForNetworkUse = true

        let exportBox = UncheckedExportBox(export)
        try await withCheckedThrowingContinuation { continuation in
            export.exportAsynchronously {
                let finishedExport = exportBox.value
                switch finishedExport.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: finishedExport.error ?? TrimExportError.exportFailed)
                default:
                    continuation.resume(throwing: TrimExportError.exportFailed)
                }
            }
        }

        return outputURL
    }

    private static func makeOutputURL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let base = sourceURL.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(base) - Schnitt.mp4")
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) - Schnitt \(index).mp4")
            index += 1
        }

        return candidate
    }
}

enum TrimExportError: LocalizedError {
    case exportUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportUnavailable:
            "Der Export ist fuer diese Datei nicht verfuegbar."
        case .exportFailed:
            "Der Schnitt konnte nicht exportiert werden."
        }
    }
}
