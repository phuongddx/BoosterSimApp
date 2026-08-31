// DesignComparisonView.swift — Side-panel UI for design overlay tools (import, safe area, grid, ruler, color, presets)
import SwiftUI
import AppKit

struct DesignComparisonView: View {

    @ObservedObject var service: DesignOverlayService

    @State private var isSafeAreaExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Comparison Mode
            Picker("Mode", selection: $service.comparisonMode) {
                ForEach(DesignOverlayService.ComparisonMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // MARK: - Import (file / paste / drag-and-drop)
            HStack(spacing: Spacing.xs) {
                Button("Open…") { service.loadImage() }
                    .buttonStyle(.bordered)

                Button("Paste") { service.importImage(from: NSPasteboard.general) }
                    .buttonStyle(.bordered)

                if service.overlayImage != nil {
                    Button("Clear") { service.clearOverlay() }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                }

                Spacer()

                if let img = service.overlayImage {
                    Text("\(Int(img.size.width))×\(Int(img.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let importError = service.importError {
                Text(importError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Text("Drop an image onto this tab to import")
                .font(.caption2)
                .foregroundColor(.secondary)

            // MARK: - Opacity Slider
            if service.overlayImage != nil && service.comparisonMode == .overlay {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Opacity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(service.overlayOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $service.overlayOpacity, in: 0...1)
                }
            }

            // MARK: - Split Position
            if service.comparisonMode == .split {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Split Position")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(service.splitPosition * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $service.splitPosition, in: 0...1)
                }
            }

            Divider()

            // MARK: - Safe Area (D-02)
            CollapsibleSection(title: "Safe Area", icon: "rectangle.dashed", isExpanded: $isSafeAreaExpanded) {
                DesignSafeAreaSection(service: service)
            }

            Divider()

            // MARK: - Grid Overlay
            Toggle(isOn: $service.showGrid) {
                Label("Grid Overlay", systemImage: "grid")
                    .font(.subheadline.bold())
            }

            if service.showGrid {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Grid Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        ColorPicker("", selection: $service.gridColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Opacity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(service.gridOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $service.gridOpacity, in: 0.05...1)
                }
            }

            Divider()

            // MARK: - Interactive Tools (ruler + color picker, 04-03)
            DesignToolsSection(service: service)

            Divider()

            // MARK: - Presets
            DesignPresetsSection(service: service)
        }
        .padding(12)
    }
}
