// CaptureTabView.swift — Screenshot + recording capture controls (recording section: RecordingSectionView)
import SwiftUI
import AppKit

struct CaptureTabView: View {

    @EnvironmentObject var captureService: CaptureService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isScreenshotExpanded = true
    @State private var isDestinationExpanded = false

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxs) {
                CollapsibleSection(title: "Screenshot", icon: "camera", isExpanded: $isScreenshotExpanded) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if captureService.permissionGranted {
                            screenshotControls
                        } else {
                            permissionSetupView
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
                    .animation(animation, value: captureService.permissionGranted)
                }
                RecordingSectionView(recording: captureService.recordingService)
                destinationSection
            }
        }
    }

    // MARK: - Screenshot Controls
    private var screenshotControls: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            pillsGrid(ASCFramePreset.self, label: { $0.displayName },
                      selection: captureService.selectedPreset,
                      action: { captureService.selectedPreset = $0 })
            pillsRow(BezelMode.self, label: { $0.label }, selection: captureService.bezelMode,
                     action: { captureService.bezelMode = $0 })
            pillsRow(CaptureBackground.self, label: { $0.label }, selection: captureService.background,
                     action: { captureService.background = $0 })
            captureButton
            statusCaption
        }
    }

    /// Two-column pill grid for option sets whose labels need width (ASC presets, destinations).
    private func pillsGrid<Value: RawRepresentable & CaseIterable & Equatable>(
        _ type: Value.Type, label: @escaping (Value) -> String,
        selection: Value, action: @escaping (Value) -> Void
    ) -> some View where Value.RawValue == String, Value.AllCases: RandomAccessCollection {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
            ForEach(Value.allCases, id: \.rawValue) { value in
                optionPill(label(value), isSelected: selection == value) { action(value) }
            }
        }
    }

    /// Single pill row for short-label option sets (house profilePill style).
    private func pillsRow<Value: RawRepresentable & CaseIterable & Equatable>(
        _ type: Value.Type, label: @escaping (Value) -> String,
        selection: Value, action: @escaping (Value) -> Void
    ) -> some View where Value.RawValue == String, Value.AllCases: RandomAccessCollection {
        HStack(spacing: Spacing.xs) {
            ForEach(Value.allCases, id: \.rawValue) { value in
                optionPill(label(value), isSelected: selection == value) { action(value) }
            }
        }
    }

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

    private var captureButton: some View {
        Button {
            captureService.takeScreenshot()
        } label: {
            Label(captureService.isCapturing ? "Capturing…" : "Capture", systemImage: "camera")
                .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.rowHeight)
        }
        .buttonStyle(.borderedProminent)
        .disabled(captureService.isCapturing)
    }

    @ViewBuilder private var statusCaption: some View {
        if captureService.isCapturing {
            captionRow(icon: "hourglass", text: "Capturing the Simulator window…", tint: .secondary)
        } else if let url = captureService.lastSavedURL {
            captionRow(icon: "checkmark.circle.fill", text: "Saved \(url.lastPathComponent)", tint: .green)
        } else if let error = captureService.lastError {
            captionRow(icon: "exclamationmark.triangle.fill", text: error, tint: .orange)
        }
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

    // MARK: - Destination

    private var destinationSection: some View {
        CollapsibleSection(title: "Destination", icon: "folder", isExpanded: $isDestinationExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                pillsGrid(CaptureDestinationKind.self, label: { $0.label },
                          selection: captureService.destinationKind,
                          action: { captureService.destinationKind = $0 })
                customFolderRow
                captionRow(icon: "info.circle", text: destinationText, tint: .secondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
    }

    @ViewBuilder private var customFolderRow: some View {
        if captureService.destinationKind == .custom, let folder = captureService.customCaptureFolder {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text(folder.lastPathComponent).font(.caption).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Show") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    .font(.caption)
            }
        }
    }

    private var destinationText: String {
        switch captureService.destinationKind {
        case .desktop: return "Saves timestamped PNGs to ~/Desktop/BoosterSim Captures."
        case .clipboard: return "Copies the PNG to the clipboard — paste into any app."
        case .custom: return "Save panel starts in your chosen folder; the choice is remembered."
        case .ask: return "Save panel asks where to save every capture."
        }
    }

    // MARK: - Permission Setup

    /// Degraded state when Screen Recording is denied: setup flow, no crash.
    private var permissionSetupView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Screen Recording Required", systemImage: "lock.shield")
            Text("BoosterSim captures only the Simulator window. Grant Screen Recording in "
                 + "System Settings, then quit and reopen the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if captureService.needsRelaunch {
                Label("Permission granted — quit and reopen BoosterSim to finish.",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.green)
                prominentButton("Quit Now", icon: "power") { NSApp.terminate(nil) }
            } else {
                prominentButton("Open System Settings", icon: "gear") {
                    captureService.requestPermission()
                }
            }
        }
    }

    private func prominentButton(_ text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.compactRowHeight)
        }
        .buttonStyle(.borderedProminent)
    }
}
