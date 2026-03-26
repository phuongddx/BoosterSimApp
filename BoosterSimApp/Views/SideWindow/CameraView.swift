// CameraView.swift — Simulator camera routing via AX menu automation (iOS only, Beta)
import SwiftUI

struct CameraView: View {

    @EnvironmentObject var service: CameraService
    let pid: pid_t?

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            if !service.isSupported {
                unsupportedRow
            } else {
                cameraRows
            }
        }
    }

    // MARK: - Sub-views

    private var sectionHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "camera.on.rectangle")
                .imageScale(.small).foregroundStyle(.secondary)
            Text("Camera")
                .font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
            Text("Beta")
                .font(.caption2).fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.orange, in: Capsule())
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
    }

    private var cameraRows: some View {
        VStack(spacing: 0) {
            cameraRow(
                label: "Front Camera",
                icon: "person.crop.rectangle",
                isEnabled: service.isFrontEnabled
            ) {
                if let pid { service.toggleFront(pid: pid) }
            }

            cameraRow(
                label: "Back Camera",
                icon: "camera.viewfinder",
                isEnabled: service.isBackEnabled
            ) {
                if let pid { service.toggleBack(pid: pid) }
            }
        }
    }

    private func cameraRow(
        label: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .imageScale(.small).frame(width: 16)
                Text(label).font(.body)
                Spacer()
                Text(isEnabled ? "Mac Camera" : "Simulated")
                    .font(.caption2)
                    .foregroundStyle(isEnabled ? .orange : .secondary)
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: SideWindowMetrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pid == nil)
    }

    private var unsupportedRow: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .imageScale(.small).foregroundStyle(.orange)
            Text("Requires Xcode 14+")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight, alignment: .leading)
    }
}

#Preview {
    CameraView(pid: nil)
        .environmentObject(CameraService())
        .frame(width: SideWindowMetrics.expandedWidth)
}
