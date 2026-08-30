// CaptureTabView.swift — Screenshot capture controls (recording arrives in plan 02)
import SwiftUI
import AppKit

struct CaptureTabView: View {

    @EnvironmentObject var captureService: CaptureService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isScreenshotExpanded = true

    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            CollapsibleSection(title: "Screenshot", icon: "camera", isExpanded: $isScreenshotExpanded) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if captureService.permissionGranted {
                        screenshotControls
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.sm)
                    } else {
                        permissionSetupView
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.sm)
                    }
                }
                .padding(.bottom, Spacing.sm)
                .animation(animation, value: captureService.permissionGranted)
                .animation(animation, value: captureService.needsRelaunch)
            }
        }
    }

    // MARK: - Screenshot Controls

    private var screenshotControls: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            presetPillsGrid
            bezelPillsRow
            backgroundPillsRow
            captureButton
            statusCaption
        }
    }

    private var presetPillsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
            ForEach(ASCFramePreset.allCases, id: \.rawValue) { preset in
                optionPill(preset.displayName, isSelected: captureService.selectedPreset == preset) {
                    captureService.selectPreset(preset)
                }
            }
        }
    }

    private var bezelPillsRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(BezelMode.allCases, id: \.rawValue) { mode in
                optionPill(mode.label, isSelected: captureService.bezelMode == mode) {
                    captureService.selectBezel(mode)
                }
            }
        }
    }

    private var backgroundPillsRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(CaptureBackground.allCases, id: \.rawValue) { fill in
                optionPill(fill.label, isSelected: captureService.background == fill) {
                    captureService.selectBackground(fill)
                }
            }
        }
    }

    private func optionPill(
        _ label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
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

    // MARK: - Permission Setup

    /// Degraded state when Screen Recording is denied: setup flow, no crash,
    /// capture controls hidden until permission lands.
    private var permissionSetupView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Screen Recording Required", systemImage: "lock.shield")
                .font(.subheadline.bold())
            Text("BoosterSim captures only the Simulator window. Grant Screen Recording in System Settings, then quit and reopen the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if captureService.needsRelaunch {
                relaunchPrompt
            } else {
                Button {
                    captureService.requestPermission()
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.compactRowHeight)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var relaunchPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Permission granted — quit and reopen BoosterSim to finish.", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.green)
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Now", systemImage: "power")
                    .frame(maxWidth: .infinity, minHeight: SideWindowMetrics.compactRowHeight)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
