// SideWindowView.swift — Root SwiftUI view hosted in SideWindowPanel
import SwiftUI

struct SideWindowView: View {

    @ObservedObject var tracker: SimulatorWindowTracker
    @ObservedObject var controller: SideWindowController
    var onHeightChanged: (() -> Void)?

    // Service environment objects injected by SideWindowController
    @EnvironmentObject var statusBarService:   StatusBarService
    @EnvironmentObject var envOverrideService: EnvironmentOverrideService
    @EnvironmentObject var buildStatsService:  BuildStatsService
    @EnvironmentObject var axInspectorService: AXInspectorService
    @EnvironmentObject var cameraService:      CameraService
    @EnvironmentObject var certificateService: CertificateService
    @EnvironmentObject var connectService:      ConnectService

    @State private var selectedTab: SideTab = .capture
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Computed helpers

    private var activeSim: SimulatorWindow? { tracker.activeSimulator }

    private var activeUDID: String? {
        guard let sim = activeSim else { return nil }
        return sim.udid ?? "booted"
    }

    // MARK: - Body

    var body: some View {
        Group {
            if controller.isCollapsed {
                CollapsedStripView(onExpand: { controller.toggleCollapsed() })
                    .transition(.opacity)
            } else {
                VStack(spacing: Spacing.sm) {
                    TabBarView(selectedTab: $selectedTab, onCollapse: { controller.toggleCollapsed() })

                    tabContent

                    SideWindowFooter()
                }
                .transition(.opacity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { _ in
            onHeightChanged?()
        }
        .animation(
            reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.8),
            value: controller.isCollapsed
        )
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .capture:
            CaptureTabView()
        case .design:
            DesignTabView()
        case .actions:
            ActionsTabView(udid: activeUDID, deviceName: activeSim?.displayName ?? "Simulator")
        case .network:
            NetworkTabView(
                udidProvider: { activeSim?.udid },
                deviceNameProvider: { activeSim?.displayName ?? "Simulator" },
                connectService: connectService
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let simCtl           = SimCtlService()
    let tracker          = SimulatorWindowTracker()
    let settings         = AppSettings()
    let statusBarService = StatusBarService(simCtl: simCtl)
    let envService       = EnvironmentOverrideService(simCtl: simCtl)
    let buildService     = BuildStatsService()
    let axService        = AXInspectorService()
    let cameraService    = CameraService()
    let certificateService = CertificateService(simCtl: simCtl)
    let connectService      = ConnectService()
    let networkConditionService = NetworkConditionService(commandServer: NoopCommandBroadcast())
    let deepLinkService = DeepLinkService()
    let appActionService = AppActionService(simCtl: simCtl, certificateService: certificateService)
    let captureService = CaptureService()
    let designComparisonService = DesignComparisonService()
    let controller       = SideWindowController(
        settings: settings, tracker: tracker,
        statusBarService: statusBarService, envOverrideService: envService,
        buildStatsService: buildService, axInspectorService: axService,
        cameraService: cameraService,
        certificateService: certificateService,
        connectService: connectService,
        networkConditionService: networkConditionService,
        deepLinkService: deepLinkService,
        designComparisonService: designComparisonService,
        captureService: captureService,
        appActionService: appActionService
    )
    SideWindowView(tracker: tracker, controller: controller)
        .environmentObject(statusBarService)
        .environmentObject(envService)
        .environmentObject(buildService)
        .environmentObject(axService)
        .environmentObject(certificateService)
        .environmentObject(networkConditionService)
        .environmentObject(connectService)
        .environmentObject(deepLinkService)
        .environmentObject(designComparisonService)
        .environmentObject(captureService)
        .environmentObject(appActionService)
}
