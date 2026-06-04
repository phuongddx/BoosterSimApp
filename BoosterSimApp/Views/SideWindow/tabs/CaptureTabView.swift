// CaptureTabView.swift — Screen capture and recording controls
import SwiftUI

struct CaptureTabView: View {

    @EnvironmentObject var captureService: CaptureService

    @State private var showExportOptions = false

    var body: some View {
        ScrollView {
            CollapsibleSection(title: "Screen Capture", icon: "video") {
                VStack(alignment: .leading, spacing: 12) {
                    // MARK: - Recording Controls
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                if captureService.isRecording {
                                    await captureService.stopRecording()
                                } else {
                                    await captureService.startRecording()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: captureService.isRecording ? "stop.fill" : "record.circle")
                                Text(captureService.isRecording ? "Stop" : "Record")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(captureService.isRecording ? .red : .accentColor)
                    }

                    // MARK: - Duration
                    if captureService.isRecording {
                        HStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text(formatDuration(captureService.recordingDuration))
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    // MARK: - Export Format
                    Picker("Format", selection: $captureService.exportFormat) {
                        ForEach(CaptureService.ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    // MARK: - Quality
                    Picker("Quality", selection: $captureService.quality) {
                        ForEach(CaptureService.CaptureQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }

                    // MARK: - Options
                    Toggle("Show Touch Indicators", isOn: $captureService.showTouchIndicators)
                        .font(.subheadline)

                    // MARK: - Bezel
                    Picker("Device Bezel", selection: $captureService.selectedBezel) {
                        ForEach(CaptureService.DeviceBezel.allCases, id: \.self) { bezel in
                            Text(bezel.rawValue).tag(bezel)
                        }
                    }

                    Divider()

                    // MARK: - Output
                    if let url = captureService.outputFileURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Export Complete", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)

                            HStack {
                                Text(url.lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                Button("Save As...") {
                                    captureService.saveToFile()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // MARK: - Error
                    if let error = captureService.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
