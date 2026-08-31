// DesignComparisonView.swift — Side-panel UI for design overlay tools (grid, ruler, color readout, presets)
import SwiftUI

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

            // MARK: - Image Controls
            HStack(spacing: 8) {
                Button("Load Image") { service.loadImage() }
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

            // MARK: - Ruler Tool
            Toggle("Ruler Tool", isOn: $service.showRuler)
                .font(.subheadline.bold())

            if service.showRuler {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(.accentColor)
                    Text("Click two points to measure distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // MARK: - Color Picker
            VStack(alignment: .leading, spacing: 6) {
                Label("Color Picker", systemImage: "eyedropper")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    if let color = service.pickedColor {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: color))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary, lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.colorToHex(color))
                                    .font(.caption.monospacedDigit())
                                Text(service.colorToRGB(color))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }

                            Button {
                                service.copyColorToClipboard()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Copy hex to clipboard")
                        }
                    }
                }
            }

            Divider()

            // MARK: - Presets
            DesignPresetsSection(service: service)
        }
        .padding(12)
    }
}
