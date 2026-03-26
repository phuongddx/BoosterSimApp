// OnboardingStepView.swift — Reusable per-step template: icon, title, description, status, CTA, skip
import SwiftUI

struct OnboardingStepView: View {

    let icon: String
    let title: String
    let description: String
    let status: BadgeStatus
    let detail: String
    let ctaTitle: String
    let ctaAction: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: OnboardingMetrics.iconSize * 0.55))
                    .foregroundStyle(.accent)
            }
            .padding(.bottom, Spacing.xl)

            // Title
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.bottom, Spacing.sm)

            // Description
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.lg)

            // Status row
            HStack(spacing: Spacing.sm) {
                StatusBadge(status: status)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.bottom, Spacing.xl)

            // Primary CTA
            AccentButton(title: ctaTitle, action: ctaAction)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.md)

            // Skip
            Button("Skip for now", action: onSkip)
                .font(.callout)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

            Spacer()
        }
        .frame(width: OnboardingMetrics.width, height: OnboardingMetrics.height)
    }
}

#Preview("Needed") {
    OnboardingStepView(
        icon: "hand.raised",
        title: "Accessibility Access",
        description: "BoosterSim needs Accessibility to track Simulator window position in real-time.",
        status: .needed,
        detail: "Required for window tracking",
        ctaTitle: "Open System Settings",
        ctaAction: {},
        onSkip: {}
    )
}

#Preview("Granted") {
    OnboardingStepView(
        icon: "hand.raised",
        title: "Accessibility Access",
        description: "BoosterSim needs Accessibility to track Simulator window position in real-time.",
        status: .granted,
        detail: "Access granted",
        ctaTitle: "Open System Settings",
        ctaAction: {},
        onSkip: {}
    )
}
