// SideWindowView.swift — Root SwiftUI view hosted in SideWindowPanel
import SwiftUI

struct SideWindowView: View {

    @ObservedObject var tracker: SimulatorWindowTracker
    @ObservedObject var controller: SideWindowController

    // Service environment objects injected by SideWindowController
    @EnvironmentObject var statusBarService:   StatusBarService
    @EnvironmentObject var envOverrideService: EnvironmentOverrideService
    @EnvironmentObject var buildStatsService:  BuildStatsService
    @EnvironmentObject var axInspectorService: AXInspectorService
    @EnvironmentObject var cameraService:      CameraService

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

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            // --- Phase 3: Environment Overrides ---
                            collapsibleSection(title: "Environment", icon: "dial.medium") {
                                EnvironmentOverridesView(udid: activeUDID)
                                    .environmentObject(envOverrideService)
                            }
                        }
                    }

                    SideWindowFooter()
                }
//                .frame(width: SideWindowMetrics.expandedWidth)
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.8),
            value: controller.isCollapsed
        )
    }

    // MARK: - Helper: wrap content in a collapsible FeatureSection-style container

    @ViewBuilder
    private func collapsibleSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        CollapsibleSectionWrapper(title: title, icon: icon, content: content)
    }
}

// MARK: - Preview

#Preview {
    let simCtl            = SimCtlService()
    let tracker           = SimulatorWindowTracker()
    let settings          = AppSettings()
    let statusBarService  = StatusBarService(simCtl: simCtl)
    let envService        = EnvironmentOverrideService(simCtl: simCtl)
    let buildService      = BuildStatsService()
    let axService         = AXInspectorService()
    let cameraService     = CameraService()
    let controller        = SideWindowController(
        settings: settings, tracker: tracker,
        statusBarService: statusBarService, envOverrideService: envService,
        buildStatsService: buildService, axInspectorService: axService,
        cameraService: cameraService
    )
    SideWindowView(tracker: tracker, controller: controller)
        .environmentObject(statusBarService)
        .environmentObject(envService)
        .environmentObject(buildService)
        .environmentObject(axService)
        .environmentObject(cameraService)
        .frame(width: SideWindowMetrics.expandedWidth, height: 600)
}

// MARK: - Collapsible Wrapper (avoids state capture issues in LazyVStack)

private struct CollapsibleSectionWrapper<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    @State private var isExpanded = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: icon).imageScale(.small).foregroundStyle(.secondary)
                        Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(height: SideWindowMetrics.compactRowHeight)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(
                            reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.75),
                            value: isExpanded
                        )
                        .padding(.trailing, Spacing.md)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.background)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
