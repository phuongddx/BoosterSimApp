// DesignSafeAreaSection.swift — Safe-area controls (D-02): toggle, resolved caption, manual inset override, calibration
// Split from DesignComparisonView.swift to hold the file-size standard (docs/code-standards).
import SwiftUI

struct DesignSafeAreaSection: View {

    @ObservedObject var service: DesignOverlayService

    /// Numeric field filter — the macOS equivalent of the iOS decimal keyboard.
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle("Show Safe Area", isOn: $service.showSafeArea)
                .font(.subheadline)

            if service.showSafeArea {
                resolvedCaption
                manualControls
                calibrationRow
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Sections

    /// Device name + the insets currently drawn (auto or manual) — what the overlay shows right now.
    private var resolvedCaption: some View {
        let insets = service.effectiveInsets
        let name = service.resolvedDeviceName ?? "No device tracked"
        return Text("\(name): T\(fmt(insets.top)) B\(fmt(insets.bottom)) "
                    + "L\(fmt(insets.left)) R\(fmt(insets.right))")
            .font(.caption.monospacedDigit())
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var manualControls: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle("Use Manual Insets", isOn: $service.useManualInsets)
                .font(.caption)

            HStack(spacing: Spacing.xs) {
                insetField("Top", value: $service.manualTop)
                insetField("Bottom", value: $service.manualBottom)
            }
            HStack(spacing: Spacing.xs) {
                insetField("Leading", value: $service.manualLeading)
                insetField("Trailing", value: $service.manualTrailing)
            }
            .disabled(!service.useManualInsets)

            // Active control — amber accent is allowed here, never on the overlay content (D-03).
            AccentButton(title: "Reset to Device Values") {
                service.resetInsetsToDevice()
            }
        }
    }

    /// Bezel escape hatch (Pitfall 3 / Open Question 5): offsets the controller adds to the content rect.
    private var calibrationRow: some View {
        HStack(spacing: Spacing.xs) {
            Text("Calibrate")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            insetField("X", value: $service.calibrationX)
            insetField("Y", value: $service.calibrationY)
        }
    }

    // MARK: - Builders

    private func insetField(_ label: String, value: Binding<CGFloat>) -> some View {
        HStack(spacing: Spacing.xxs) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: Spacing.xxl * 2, alignment: .leading)
            TextField("", value: value, formatter: Self.numberFormatter)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospacedDigit())
        }
    }

    private func fmt(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
