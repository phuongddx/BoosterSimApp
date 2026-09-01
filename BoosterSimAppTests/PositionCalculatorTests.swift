// PositionCalculatorTests.swift — Pure frame-math contract for all 4 side-window positions
// Excludes screen(containing:) — it reads live NSScreen state, which is not deterministic.
import Foundation
import CoreGraphics
import Testing
@testable import BoosterSimApp

struct PositionCalculatorTests {

    // Fixed synthetic geometry — no live NSScreen dependency anywhere in this suite.
    let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    // Mid-screen simulator: 600×600 at (660, 240) — fits on either side, clear of all edges.
    let midSim = CGRect(x: 660, y: 240, width: 600, height: 600)

    // MARK: - .right

    @Test func rightPlacesPanelAtSimulatorMaxX() {
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        // x == sim.maxX (fits: 1260 + 260 <= 1920); y centered on sim.midY (540 - 250)
        #expect(frame == CGRect(x: 1260, y: 290, width: SideWindowMetrics.expandedWidth, height: 500))
    }

    @Test func rightClampsToScreenWhenSimulatorOverflowsRightEdge() {
        // maxX 2300 + 260 would overflow; x clamps to screen.maxX - width
        let sim = CGRect(x: 1700, y: 240, width: 600, height: 600)
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == CGRect(x: 1920 - SideWindowMetrics.expandedWidth, y: 290,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }

    @Test func rightClampBoundaryIsExact() {
        // sim.maxX + width == screen.maxX exactly → clamp value equals unclamped value
        let sim = CGRect(x: 1060, y: 240, width: 600, height: 600)   // maxX == 1660 == 1920 - 260
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame.minX == screen.maxX - SideWindowMetrics.expandedWidth)
    }

    // MARK: - .left

    @Test func leftPlacesPanelInsideSimulatorMinX() {
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .left,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == CGRect(x: 660 - SideWindowMetrics.expandedWidth, y: 290,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }

    @Test func leftClampsToScreenMinXWhenSimulatorHugsLeftEdge() {
        let sim = CGRect(x: 0, y: 240, width: 600, height: 600)      // minX at screen edge
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .left,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == CGRect(x: 0, y: 290,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }

    @Test func leftClampEngagesExactlyAtBoundary() {
        // sim.minX - width crosses below screen.minX → x pins to 0; above it → unclamped
        let crossing = CGRect(x: 100, y: 240, width: 600, height: 600)   // 100 - 260 < 0
        let clear = CGRect(x: 300, y: 240, width: 600, height: 600)      // 300 - 260 = 40 >= 0
        let clamped = PositionCalculator.panelFrame(
            simulatorFrame: crossing, position: .left,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        let unclamped = PositionCalculator.panelFrame(
            simulatorFrame: clear, position: .left,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(clamped.minX == screen.minX)
        #expect(unclamped.minX == 40)
    }

    // MARK: - Collapsed width

    @Test func collapsedSwitchesWidthAcrossSidePositions() {
        let right = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .right,
            screenFrame: screen, isCollapsed: true, contentHeight: 500
        )
        let left = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .left,
            screenFrame: screen, isCollapsed: true, contentHeight: 500
        )
        let dynamic = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .dynamic,
            screenFrame: screen, isCollapsed: true, contentHeight: 500
        )
        #expect(right == CGRect(x: 1260, y: 290, width: SideWindowMetrics.collapsedWidth, height: 500))
        #expect(left == CGRect(x: 660 - SideWindowMetrics.collapsedWidth, y: 290,
                               width: SideWindowMetrics.collapsedWidth, height: 500))
        // dynamic resolves right for the mid-screen sim
        #expect(dynamic == right)
    }

    // MARK: - Height floor

    @Test func heightFloorsAtMinHeightBelowIt() {
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 200
        )
        #expect(frame == CGRect(x: 1260, y: 340,
                                width: SideWindowMetrics.expandedWidth, height: SideWindowMetrics.minHeight))
    }

    @Test func heightFollowsContentAboveTheFloor() {
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 600
        )
        #expect(frame == CGRect(x: 1260, y: 240,
                                width: SideWindowMetrics.expandedWidth, height: 600))
    }

    // MARK: - .bottom

    @Test func bottomUsesFixedHeightAndSimulatorWidth() {
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .bottom,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        // Fixed 200pt strip spanning the simulator width, directly below it
        #expect(frame == CGRect(x: 660, y: 240 - 200, width: 600, height: 200))
    }

    @Test func bottomIgnoresCollapsedAndContentHeight() {
        let collapsed = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .bottom,
            screenFrame: screen, isCollapsed: true, contentHeight: 900
        )
        #expect(collapsed == CGRect(x: 660, y: 240 - 200, width: 600, height: 200))
    }

    @Test func bottomClampsToScreenMinY() {
        let sim = CGRect(x: 660, y: 100, width: 600, height: 600)    // minY - 200 < 0
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .bottom,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == CGRect(x: 660, y: 0, width: 600, height: 200))
    }

    @Test func bottomClampBoundaryIsExact() {
        // sim.minY == 200 exactly → y == screen.minY on both paths
        let sim = CGRect(x: 660, y: 200, width: 600, height: 600)
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .bottom,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame.minY == screen.minY)
    }

    // MARK: - .dynamic

    @Test func dynamicPrefersRightWhenRightSpaceFits() {
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .dynamic,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        // rightSpace 660 >= 260 → identical to .right
        let right = PositionCalculator.panelFrame(
            simulatorFrame: midSim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == right)
    }

    @Test func dynamicPrefersRightWhenRightSpaceExactlyEqualsWidth() {
        // Boundary: rightSpace == width (>= is inclusive)
        let sim = CGRect(x: 1060, y: 240, width: 600, height: 600)   // maxX 1660, rightSpace 260
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .dynamic,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame.minX == sim.maxX)
    }

    @Test func dynamicFallsBackLeftWhenOnlyLeftFits() {
        // rightSpace -80 < 260; leftSpace 1400 >= 260
        let sim = CGRect(x: 1400, y: 240, width: 600, height: 600)
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .dynamic,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        let left = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .left,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == left)
        #expect(frame == CGRect(x: 1140, y: 290,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }

    @Test func dynamicFallsBackRightWhenNeitherSideFits() {
        // rightSpace 60 < 260 AND leftSpace 60 < 260 → right frame (overlapping, edge-clamped)
        let sim = CGRect(x: 60, y: 240, width: 1800, height: 600)
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .dynamic,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        let right = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == right)
        #expect(frame == CGRect(x: 1920 - SideWindowMetrics.expandedWidth, y: 290,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }

    // MARK: - centeredY clamping

    @Test func centeredYClampsTop() {
        // Panel centered on sim.midY 960 would place it above the screen's usable top
        let sim = CGRect(x: 660, y: 880, width: 600, height: 160)
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == CGRect(x: 1260, y: 1080 - 500,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }

    @Test func centeredYClampsBottom() {
        // sim.midY 100 → ideal y -150 → clamps to screen.minY
        let sim = CGRect(x: 660, y: 0, width: 600, height: 200)
        let frame = PositionCalculator.panelFrame(
            simulatorFrame: sim, position: .right,
            screenFrame: screen, isCollapsed: false, contentHeight: 500
        )
        #expect(frame == CGRect(x: 1260, y: 0,
                                width: SideWindowMetrics.expandedWidth, height: 500))
    }
}
