// RecordingSectionView.swift — Recording controls, live stats, staged output row
import SwiftUI
import AppKit

struct RecordingSectionView: View {

    @EnvironmentObject private var captureService: CaptureService
    @ObservedObject private var recording: RecordingService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    init(recording: RecordingService) {
        self.recording = recording
    }

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Recording", icon: "video", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !captureService.permissionGranted {
                    captionRow(icon: "lock.shield", text: "Screen Recording permission required",
                               tint: .secondary)
                }
                recordButton
                captionRow(icon: "gauge", text: fpsText, tint: .secondary)
                touchIndicatorToggle
                if let hint = captureService.touchIndicatorHint {
                    captionRow(icon: "arrow.triangle.2.circlepath", text: hint, tint: .orange)
                }
                if recording.state.isWorking {
                    captionRow(icon: "clock", text: liveStatsText, tint: .red)
                }
                stagedRecordingRow
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: recording.state)
        }
    }

    // MARK: - Controls

    private var recordButton: some View {
        Button {
            if recording.state == .recording {
                captureService.stopRecording()
            } else {
                captureService.startRecording()
            }
        } label: {
            Label(buttonTitle, systemImage: recording.state == .recording ? "stop.fill" : "video")
                .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.rowHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(recording.state == .recording ? Color.red : Color.accentColor)
        .disabled(recording.state == .finishing || !captureService.permissionGranted)
    }

    private var buttonTitle: String {
        switch recording.state {
        case .recording: return "Stop"
        case .finishing: return "Finishing…"
        default: return "Record"
        }
    }

    private var touchIndicatorToggle: some View {
        Toggle("Show touch indicators", isOn: $captureService.showTouchIndicators)
            .font(.caption)
            .toggleStyle(.switch)
            .controlSize(.small)
    }

    // MARK: - Captions

    /// Honest rate wording — delivered frames are bounded by the display (Pitfall 5).
    private var fpsText: String {
        "Up to 120 fps — delivered frames follow your display's refresh rate"
    }

    private var liveStatsText: String {
        let seconds = Int(recording.elapsed.rounded())
        let elapsed = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        let size = ByteCountFormatter.string(fromByteCount: recording.outputBytes, countStyle: .file)
        return recording.state == .finishing ? "\(elapsed) • \(size) — finalizing…" : "\(elapsed) • \(size)"
    }

    private func captionRow(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Staged Recording

    @ViewBuilder private var stagedRecordingRow: some View {
        if case .exported(let url) = recording.state {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "film").foregroundStyle(.secondary)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .font(.caption)
            }
            .padding(Spacing.sm)
            .background(Color.secondary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }
}
