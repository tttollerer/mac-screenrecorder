import Foundation

enum RecordingFileNamer {
    static func makeOutputURL(in folderPath: String, sourceTitle: String) throws -> URL {
        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let date = formatter.string(from: Date())
        let cleanTitle = sourceTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let base = cleanTitle.isEmpty ? "Web-App Demo" : cleanTitle
        return folder.appendingPathComponent("\(date) - \(base).mp4")
    }
}
