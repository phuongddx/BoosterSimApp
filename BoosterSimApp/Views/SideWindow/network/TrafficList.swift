// TrafficList.swift — Scrollable list of captured network requests
import SwiftUI

struct TrafficList: View {

    let events: [NetworkEvent]
    @Binding var selectedEvent: NetworkEvent?
    var onRequestClear: (() -> Void)?

    var body: some View {
        Group {
            if events.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(events) { event in
                        TrafficRowView(event: event, isSelected: selectedEvent?.id == event.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                            .id(event.id)
                    }
                }
            }
            .onChange(of: events.count) { _, _ in
                // Auto-scroll to latest request
                if let last = events.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer().frame(height: Spacing.xxl)
            Image(systemName: "network")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No network traffic")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let events: [NetworkEvent] = [
        .init(method: .GET, url: "https://api.example.com/users", statusCode: 200, duration: 0.142),
        .init(method: .POST, url: "https://api.example.com/login", statusCode: 401, duration: 0.89),
        .init(method: .GET, url: "https://cdn.example.com/image.png", statusCode: 200, duration: 0.34),
    ]
    TrafficList(events: events, selectedEvent: .constant(nil))
        .frame(width: SideWindowMetrics.expandedWidth, height: 300)
}
