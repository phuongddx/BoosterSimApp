// OnboardingContainerView.swift — 4-step permission wizard with TabView + slide transitions
import SwiftUI

struct OnboardingContainerView: View {

    @StateObject private var permissions = PermissionManager()
    @AppStorage("completedOnboarding") private var completed = false
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            // Step content via TabView (no tab bar shown; we drive selection ourselves)
            TabView(selection: $currentStep) {
                // Step 0: Accessibility
                OnboardingStepView(
                    icon: "hand.raised",
                    title: "Accessibility Access",
                    description: "BoosterSim needs Accessibility to track Simulator window position in real-time.",
                    status: permissions.accessibilityGranted ? .granted : .needed,
                    detail: permissions.accessibilityGranted ? "Access granted" : "Required for window tracking",
                    ctaTitle: "Open System Settings",
                    ctaAction: {
                        permissions.openAccessibilitySettings()
                        permissions.startAccessibilityPolling { advance() }
                    },
                    onSkip: advance
                )
                .tag(0)

                // Step 1: Xcode
                OnboardingStepView(
                    icon: "hammer",
                    title: "Select Xcode",
                    description: "BoosterSim uses Xcode tools to access build information.",
                    status: permissions.xcodeDetected ? .granted : .needed,
                    detail: permissions.xcodePath ?? "Xcode not found",
                    ctaTitle: permissions.xcodeDetected ? "Detected ✓" : "Browse...",
                    ctaAction: {
                        permissions.selectXcodeManually()
                        if permissions.xcodeDetected { advance() }
                    },
                    onSkip: advance
                )
                .tag(1)

                // Step 2: Screen Recording
                OnboardingStepView(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Allows BoosterSim to read Simulator window titles (device names).",
                    status: permissions.screenRecordingGranted ? .granted : .needed,
                    detail: permissions.screenRecordingGranted ? "Access granted" : "Optional — enables device names",
                    ctaTitle: "Open System Settings",
                    ctaAction: {
                        permissions.openScreenRecordingSettings()
                        permissions.startScreenRecordingPolling { advance() }
                    },
                    onSkip: advance
                )
                .tag(2)

                // Step 3: DerivedData
                OnboardingStepView(
                    icon: "folder",
                    title: "DerivedData Access",
                    description: "Grant access to Xcode's DerivedData folder to read build artifacts.",
                    status: permissions.derivedDataAccessGranted ? .granted : .needed,
                    detail: permissions.derivedDataURL?.path ?? "Not selected",
                    ctaTitle: "Select Folder...",
                    ctaAction: {
                        permissions.selectDerivedData()
                        if permissions.derivedDataAccessGranted { finishOnboarding() }
                    },
                    onSkip: finishOnboarding
                )
                .tag(3)
            }
            .tabViewStyle(.automatic)

            // Progress dots + step label
            VStack(spacing: Spacing.xs) {
                ProgressDotsView(total: OnboardingMetrics.steps, current: currentStep)
                Text("Step \(currentStep + 1) of \(OnboardingMetrics.steps)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, Spacing.lg)
        }
        .frame(width: OnboardingMetrics.width, height: OnboardingMetrics.height)
        .onAppear { permissions.checkAll() }
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentStep < OnboardingMetrics.steps - 1 {
                currentStep += 1
            } else {
                finishOnboarding()
            }
        }
    }

    private func finishOnboarding() {
        completed = true
        // Close the onboarding window
        NSApp.windows.first { $0.title == "Welcome to BoosterSim" }?.close()
    }
}
