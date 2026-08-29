// NetworkTabView.swift — Network tab: live traffic viewer + certificates
import SwiftUI

struct NetworkTabView: View {

    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var certificateService: CertificateService
    @ObservedObject var connectService: ConnectService
    @EnvironmentObject var networkConditionService: NetworkConditionService

    @State private var filter = TrafficFilter()
    @State private var selectedEvent: NetworkEvent?
    @State private var showSetup = false

    // MARK: - Computed

    private var filteredEvents: [NetworkEvent] {
        connectService.networkEvents.filter { filter.matches($0) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Connection status banner
            ConnectStatusBanner(
                state: connectService.connectionState,
                onSetupTap: { showSetup = true }
            )

            if showSetup || connectService.connectionState == .disconnected && connectService.networkEvents.isEmpty {
                // Setup instructions when not connected and no events
                ConnectSetupView()
            } else {
                // Live traffic viewer
                TrafficFilterBar(
                    filter: $filter,
                    eventCount: filteredEvents.count,
                    onClear: { connectService.clearEvents() }
                )

                TrafficList(
                    events: filteredEvents,
                    selectedEvent: $selectedEvent,
                    onRequestClear: { connectService.clearEvents() }
                )
            }

            Divider()

            // Network conditions (airplane) — pushed to apps embedding BoosterSimConnect
            NetworkConditionsSectionView()

            // Certificate section (always visible)
            CertificateSectionView(
                udidProvider: udidProvider,
                deviceNameProvider: deviceNameProvider
            )
        }
        .sheet(item: $selectedEvent) { event in
            TrafficDetailView(event: event)
                .frame(width: SideWindowMetrics.expandedWidth, height: 400)
        }
    }
}
