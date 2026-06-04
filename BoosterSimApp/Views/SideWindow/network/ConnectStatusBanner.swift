// ConnectStatusBanner.swift — Slim banner showing Simulator connection status
import SwiftUI

struct ConnectStatusBanner: View {

    let state: ConnectionState
    let onSetupTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Status dot
            statusDot

            // Label
            Text(state.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Action button
            switch state {
            case .disconnected:
                Button("Setup", action: onSetupTap)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.plain)
            case .searching:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            case .connected:
                EmptyView()
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.compactRowHeight)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Status Dot

    @ViewBuilder
    private var statusDot: some View {
        switch state {
        case .disconnected:
            Circle().fill(.secondary).frame(width: 6, height: 6)
        case .searching:
            Circle().fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .modifier(PulseModifier(reduceMotion: reduceMotion))
        case .connected:
            Circle().fill(.green).frame(width: 6, height: 6)
        }
    }
}

// MARK: - Pulsing Animation Modifier

private struct PulseModifier: ViewModifier {
    let reduceMotion: Bool

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        ConnectStatusBanner(state: .disconnected, onSetupTap: {})
        ConnectStatusBanner(state: .searching, onSetupTap: {})
        ConnectStatusBanner(state: connected("iPhone 16"), onSetupTap: {})
    }
    .frame(width: SideWindowMetrics.expandedWidth)
}

private func connected(_ name: String) -> ConnectionState {
    .connected(name)
}
