// ExportSectionView.swift — Export controls (format/GIF tuning, progress, cancel, reveal)
import SwiftUI
import AppKit

struct ExportSectionView: View {

    @EnvironmentObject private var captureService: CaptureService
    @ObservedObject private var exporter: CaptureExporter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private let gifWidths = [480, 640]
    private let gifFrameRates = [5, 10]

    init(exporter: CaptureExporter) {
        self.exporter = exporter
    }

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(title: "Export", icon: "film", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                formatPills
                if captureService.exportFormat == .gif { gifTuning }
                exportControls
                statusCaption
                captionRow(icon: "info.circle", text: destinationText, tint: .secondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)
            .animation(animation, value: captureService.exportFormat)
            .animation(animation, value: exporter.exportState)
        }
    }

    // MARK: - Controls

    private var formatPills: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(CaptureExportFormat.allCases, id: \.rawValue) { format in
                optionPill(format.label, isSelected: captureService.exportFormat == format) {
                    captureService.exportFormat = format
                }
            }
        }
    }

    /// GIF-only tuning — width and fps pills appear for the GIF format alone.
    private var gifTuning: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ForEach(gifWidths, id: \.self) { width in
                    optionPill("\(width) px", isSelected: captureService.gifSize == width) {
                        captureService.gifSize = width
                    }
                }
            }
            HStack(spacing: Spacing.xs) {
                ForEach(gifFrameRates, id: \.self) { fps in
                    optionPill("\(fps) fps", isSelected: captureService.gifFPS == fps) {
                        captureService.gifFPS = fps
                    }
                }
            }
        }
    }

    @ViewBuilder private var exportControls: some View {
        if case .running(let progress) = exporter.exportState {
            HStack(spacing: Spacing.sm) {
                ProgressView(value: progress)
                Button("Cancel") { captureService.cancelExport() }
                    .buttonStyle(.bordered)
            }
        } else {
            Button {
                captureService.exportRecording(as: captureService.exportFormat)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.rowHeight)
            }
            .buttonStyle(.borderedProminent)
            .disabled(captureService.stagedRecordingURL == nil)
        }
    }

    // MARK: - Captions

    @ViewBuilder private var statusCaption: some View {
        switch exporter.exportState {
        case .running(let progress):
            captionRow(icon: "hourglass", text: "Exporting… \(Int((progress * 100).rounded()))%",
                       tint: .secondary)
        case .cancelled:
            captionRow(icon: "xmark.circle", text: "Export cancelled — the recording is kept",
                       tint: .secondary)
        case .failed(let message):
            captionRow(icon: "exclamationmark.triangle.fill", text: message, tint: .orange)
        default:
            completionCaption
        }
    }

    /// Completion with the reveal action — the durable URL the router saved.
    @ViewBuilder private var completionCaption: some View {
        if let url = captureService.lastSavedURL {
            HStack(spacing: Spacing.xs) {
                captionRow(icon: "checkmark.circle.fill", text: "Saved \(url.lastPathComponent)",
                           tint: .green)
                Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .font(.caption)
            }
        }
    }

    private var destinationText: String {
        switch captureService.destinationKind {
        case .desktop: return "Exports save beside your PNGs in ~/Desktop/BoosterSim Captures."
        case .clipboard: return "Exports copy the file to the clipboard — paste into Finder to save it."
        case .custom: return "The save panel starts in your chosen folder with the right extension."
        case .ask: return "The save panel asks where to save every export."
        }
    }

    // MARK: - Pills (house profilePill style)

    private func optionPill(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.compactRowHeight)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(0.15)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
}
