// DesignTokens.swift — Design system constants from design-guidelines.md
// 4pt grid spacing, amber accent, side window dimensions

import Foundation

// MARK: - Spacing (4pt grid)
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

// MARK: - Corner Radii
enum CornerRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 6
    static let large: CGFloat = 8
    static let panel: CGFloat = 10
    static let onboarding: CGFloat = 12
}

// MARK: - Side Window Dimensions
enum SideWindowMetrics {
    static let expandedWidth: CGFloat = 260
    static let collapsedWidth: CGFloat = 28
    static let minHeight: CGFloat = 400
    static let rowHeight: CGFloat = 32
    static let compactRowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 36
    static let titleBarHeight: CGFloat = 28
}

// MARK: - Onboarding Dimensions
enum OnboardingMetrics {
    static let width: CGFloat = 480
    static let height: CGFloat = 520
    static let iconSize: CGFloat = 48
    static let dotSize: CGFloat = 8
    static let steps: Int = 4
}

// MARK: - Preferences Dimensions
enum PreferencesMetrics {
    static let width: CGFloat = 500
    static let height: CGFloat = 380
    static let rowHeight: CGFloat = 36
}

// MARK: - Overlay Tool Metrics (04-03)
enum OverlayMetrics {
    static let markerRadius: CGFloat = 3
    static let readoutInset: CGFloat = Spacing.sm
    static let loupeDiameter: CGFloat = 96
    static let loupeMagnificationDefault: Double = 8
    static let loupeMagnificationRange: ClosedRange<Double> = 2...16
}
