// DesignToolsSection.swift — Ruler + Color Picker side-panel sections (04-03 interactive tools)
// Extracted from DesignComparisonView to hold the file-size standard (04-02 precedent).
// Active controls may use the accent (amber) — overlay content never does (D-03).
import SwiftUI

struct DesignToolsSection: View {

    @ObservedObject var service: DesignOverlayService

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            rulerSection
            Divider()
            pickerSection
        }
    }

    // MARK: - Ruler

    private var rulerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Ruler", systemImage: "ruler")
                .font(.subheadline.bold())

            // The arm/disarm pair across states: the CTA flips with the tool.
            if service.isRulerArmed {
                AccentButton(title: "Stop Measuring") { service.disarmRuler() }
            } else {
                AccentButton(title: "Measure") { service.armRuler() }
            }

            if let distance = service.rulerDistance {
                HStack {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(distance)
                        .font(.caption.monospacedDigit())
                }
            }
        }
    }

    // MARK: - Color Picker

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Color Picker", systemImage: "eyedropper")
                .font(.subheadline.bold())

            if service.isMagnifierArmed {
                AccentButton(title: "Stop Picking") { service.disarmMagnifier() }
            } else {
                AccentButton(title: "Pick Color") { service.armMagnifier() }
            }

            Stepper(value: $service.magnification, in: OverlayMetrics.loupeMagnificationRange) {
                Text("Magnification \(Int(service.magnification))×")
                    .font(.caption.monospacedDigit())
            }

            if let error = service.samplerError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if let color = service.pickedColor {
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color(nsColor: color))
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.small)
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
                    Spacer()
                }
            }
        }
    }
}
