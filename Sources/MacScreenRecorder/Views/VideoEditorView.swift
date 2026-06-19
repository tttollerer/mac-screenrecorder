import AVFoundation
import AVKit
import SwiftUI

struct VideoEditorView: View {
    @EnvironmentObject private var recorder: RecordingCoordinator
    let recordingURL: URL

    @State private var player = AVPlayer()
    @State private var durationSeconds: Double = 0
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var exportedURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider()

            HStack(alignment: .top, spacing: 20) {
                VideoPlayer(player: player)
                    .frame(minWidth: 520, minHeight: 320)
                    .background(.black, in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 16) {
                    trimControls
                    exportControls
                }
                .frame(width: 300)
            }
            .padding(24)
        }
        .task {
            await loadVideo()
        }
        .onDisappear {
            player.pause()
        }
    }

    private var editorHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schnitt")
                    .font(.system(size: 22, weight: .semibold))
                Text(recordingURL.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                recorder.closeEditor()
            } label: {
                Label("Recorder", systemImage: "record.circle")
            }
            .controlSize(.large)
        }
    }

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Trimmen", systemImage: "timeline.selection")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start")
                    Spacer()
                    Text(formatTime(trimStart))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(value: $trimStart, in: 0...max(durationSeconds, 0.2)) {
                    Text("Start")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text(formatTime(durationSeconds))
                }
                .onChange(of: trimStart) { _, newValue in
                    if newValue >= trimEnd {
                        trimEnd = min(durationSeconds, newValue + 0.2)
                    }
                    seek(to: trimStart)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ende")
                    Spacer()
                    Text(formatTime(trimEnd))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(value: $trimEnd, in: 0...max(durationSeconds, 0.2)) {
                    Text("Ende")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text(formatTime(durationSeconds))
                }
                .onChange(of: trimEnd) { _, newValue in
                    if newValue <= trimStart {
                        trimStart = max(0, newValue - 0.2)
                    }
                }
            }

            HStack {
                Button {
                    seek(to: trimStart)
                    player.play()
                } label: {
                    Label("Abspielen", systemImage: "play.fill")
                }

                Button {
                    player.pause()
                    seek(to: trimStart)
                } label: {
                    Label("Zurueck", systemImage: "backward.end.fill")
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var exportControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export", systemImage: "square.and.arrow.down")
                .font(.headline)

            Text("Laenge: \(formatTime(max(0, trimEnd - trimStart)))")
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Button {
                Task { await exportTrimmedVideo() }
            } label: {
                Label(isExporting ? "Exportiert..." : "Schnitt exportieren", systemImage: "scissors")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting || trimEnd <= trimStart)

            if let exportedURL {
                HStack {
                    Button {
                        NSWorkspace.shared.open(exportedURL)
                    } label: {
                        Label("Oeffnen", systemImage: "play.rectangle")
                    }

                    ShareLink(item: exportedURL) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func loadVideo() async {
        let item = AVPlayerItem(url: recordingURL)
        player.replaceCurrentItem(with: item)

        do {
            let asset = AVURLAsset(url: recordingURL)
            let duration = try await asset.load(.duration)
            durationSeconds = max(0, duration.seconds)
            trimStart = 0
            trimEnd = durationSeconds
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func exportTrimmedVideo() async {
        isExporting = true
        errorMessage = nil

        do {
            let url = try await TrimExportService.exportTrimmedCopy(
                sourceURL: recordingURL,
                startSeconds: trimStart,
                endSeconds: trimEnd
            )
            exportedURL = url
            recorder.lastRecordingURL = url
            recorder.statusMessage = "Schnitt gespeichert: \(url.lastPathComponent)"
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
