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
    @EnvironmentObject var healthDataService:  HealthDataService
    @EnvironmentObject var certificateService: CertificateService

    // Selected simulator index (for multi-device picker in DeviceHeaderView)
    @State private var selectedSimIndex = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Computed helpers

    private var selectedSim: SimulatorWindow? {
        guard !tracker.simulators.isEmpty,
              selectedSimIndex < tracker.simulators.count else { return tracker.activeSimulator }
        return tracker.simulators[selectedSimIndex]
    }

    // Fall back to "booted" when sim is detected but UDID is nil (Screen Recording not granted)
    private var activeUDID: String? {
        guard selectedSim != nil else { return nil }
        return selectedSim?.udid ?? "booted"
    }
    private var activePID:  pid_t?  { selectedSim?.pid  }
    private var deviceType: SimulatorDeviceType { selectedSim?.deviceType ?? .iOS }

    // MARK: - Feature item lists (existing "Coming soon" sections)

    private let captureItems: [FeatureItem] = [
        FeatureItem(icon: "camera",               label: "Screenshot"),
        FeatureItem(icon: "video",                label: "Record Screen"),
        FeatureItem(icon: "film",                 label: "GIF Recording"),
        FeatureItem(icon: "square.and.arrow.up",  label: "Video Export")
    ]
    private let actionItems: [FeatureItem] = [
        FeatureItem(icon: "arrow.counterclockwise", label: "Reset App"),
        FeatureItem(icon: "key",                    label: "Clear Keychain"),
        FeatureItem(icon: "bell",                   label: "Push Notification"),
        FeatureItem(icon: "link",                   label: "Deep Link")
    ]
    private let designItems: [FeatureItem] = [
        FeatureItem(icon: "grid",               label: "Grid Overlay"),
        FeatureItem(icon: "rectangle.dashed",   label: "Safe Area Overlay"),
        FeatureItem(icon: "ruler",              label: "Ruler"),
        FeatureItem(icon: "eyedropper",         label: "Color Picker")
    ]
    private let networkItems: [FeatureItem] = [
        FeatureItem(icon: "tortoise",                   label: "Throttle Network"),
        FeatureItem(icon: "xmark.shield",               label: "Block Requests"),
        FeatureItem(icon: "list.bullet.rectangle",      label: "View Logs"),
        FeatureItem(icon: "lock.shield",                label: "Certificates")
    ]

    // MARK: - Body

    var body: some View {
        Group {
            if controller.isCollapsed {
                CollapsedStripView(onExpand: { controller.toggleCollapsed() })
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    SideWindowTitleBar(onCollapse: { controller.toggleCollapsed() })

                    DeviceHeaderView(tracker: tracker, selectedIndex: $selectedSimIndex)

                    EnvironmentOverridesView(udid: activeUDID)
                        .environmentObject(envOverrideService)

                    CertificateSectionView(
                        udidProvider: { selectedSim?.udid },
                        deviceNameProvider: { selectedSim?.displayName ?? "Simulator" }
                    )
                    .environmentObject(certificateService)

                    HealthDataSectionView(udid: activeUDID ?? "booted")
                        .environmentObject(healthDataService)

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
    let healthService    = HealthDataService(simCtl: simCtl)
    let certificateService = CertificateService(simCtl: simCtl)
    let controller       = SideWindowController(
        settings: settings, tracker: tracker,
        statusBarService: statusBarService, envOverrideService: envService,
        buildStatsService: buildService, axInspectorService: axService,
        cameraService: cameraService, healthDataService: healthService,
        certificateService: certificateService
    )
    SideWindowView(tracker: tracker, controller: controller)
        .environmentObject(statusBarService)
        .environmentObject(envService)
        .environmentObject(buildService)
        .environmentObject(axService)
        .environmentObject(cameraService)
        .environmentObject(healthService)
        .environmentObject(certificateService)
        .frame(width: SideWindowMetrics.expandedWidth, height: 600)
}
