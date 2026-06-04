// TrafficRowView.swift — Single network request row in traffic list
import SwiftUI

struct TrafficRowView: View {

    let event: NetworkEvent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Method badge
            methodBadge

            // URL path (truncated)
            Text(event.shortPath)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            // Status code
            if let code = event.statusCode {
                Text("\(code)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }

            // Duration
            Text(event.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    // MARK: - Method Badge

    private var methodBadge: some View {
        Text(event.method.rawValue)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(methodForeground)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(methodBackground)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var methodForeground: Color {
        switch event.method {
        case .GET:    return .green
        case .POST:   return .orange
        case .PUT:    return .blue
        case .PATCH:  return .purple
        case .DELETE: return .red
        default:      return .secondary
        }
    }

    private var methodBackground: Color {
        methodForeground.opacity(0.12)
    }

    // MARK: - Status Color

    private var statusColor: Color {
        guard let code = event.statusCode else { return .secondary }
        switch code {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        default:        return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        TrafficRowView(event: NetworkEvent(
            method: .GET, url: "https://api.example.com/users/123",
            statusCode: 200, duration: 0.142
        ), isSelected: false)
        TrafficRowView(event: NetworkEvent(
            method: .POST, url: "https://api.example.com/users",
            statusCode: 401, duration: 0.89
        ), isSelected: true)
        TrafficRowView(event: NetworkEvent(
            method: .DELETE, url: "https://api.example.com/items/456",
            statusCode: 500, duration: 2.3
        ), isSelected: false)
    }
    .frame(width: SideWindowMetrics.expandedWidth)
}
