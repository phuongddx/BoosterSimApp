// PositionCalculator.swift — Pure frame math for all 4 side window positions
// CGRect coordinates: origin is bottom-left on macOS screen (flipped from AppKit window).
import AppKit

enum PositionCalculator {

    // MARK: - Public API

    /// Calculates the panel frame relative to the simulator window and screen.
    /// - Parameters:
    ///   - simulatorFrame: Simulator window frame in screen coordinates
    ///   - position: Requested side window position mode
    ///   - screenFrame: Visible frame of the screen containing the simulator
    ///   - isCollapsed: Whether the panel is in collapsed (28pt) mode
    static func panelFrame(
        simulatorFrame: CGRect,
        position: SideWindowPosition,
        screenFrame: CGRect,
        isCollapsed: Bool,
        contentHeight: CGFloat
    ) -> CGRect {
        let panelWidth = isCollapsed ? SideWindowMetrics.collapsedWidth : SideWindowMetrics.expandedWidth
        let panelHeight = max(contentHeight, SideWindowMetrics.minHeight)

        switch position {
        case .right:
            return rightFrame(sim: simulatorFrame, width: panelWidth, height: panelHeight, screen: screenFrame)
        case .left:
            return leftFrame(sim: simulatorFrame, width: panelWidth, height: panelHeight, screen: screenFrame)
        case .bottom:
            return bottomFrame(sim: simulatorFrame, screen: screenFrame)
        case .dynamic:
            return dynamicFrame(sim: simulatorFrame, width: panelWidth, height: panelHeight, screen: screenFrame)
        }
    }

    // MARK: - Position Helpers

    private static func rightFrame(sim: CGRect, width: CGFloat, height: CGFloat, screen: CGRect) -> CGRect {
        let x = min(sim.maxX, screen.maxX - width)
        let y = centeredY(sim: sim, height: height, screen: screen)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func leftFrame(sim: CGRect, width: CGFloat, height: CGFloat, screen: CGRect) -> CGRect {
        let x = max(sim.minX - width, screen.minX)
        let y = centeredY(sim: sim, height: height, screen: screen)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func centeredY(sim: CGRect, height: CGFloat, screen: CGRect) -> CGFloat {
        let ideal = sim.midY - height / 2
        return max(screen.minY, min(ideal, screen.maxY - height))
    }

    private static func bottomFrame(sim: CGRect, screen: CGRect) -> CGRect {
        let bottomHeight: CGFloat = 200
        let y = max(sim.minY - bottomHeight, screen.minY)
        return CGRect(x: sim.minX, y: y, width: sim.width, height: bottomHeight)
    }

    private static func dynamicFrame(sim: CGRect, width: CGFloat, height: CGFloat, screen: CGRect) -> CGRect {
        let rightSpace = screen.maxX - sim.maxX
        let leftSpace = sim.minX - screen.minX

        if rightSpace >= width {
            return rightFrame(sim: sim, width: width, height: height, screen: screen)
        } else if leftSpace >= width {
            return leftFrame(sim: sim, width: width, height: height, screen: screen)
        } else {
            // Not enough space on either side — default to right, may overlap edge
            return rightFrame(sim: sim, width: width, height: height, screen: screen)
        }
    }

    // MARK: - Screen Lookup

    /// Finds the screen that best contains the given rect (by intersection area).
    static func screen(containing rect: CGRect) -> NSScreen {
        NSScreen.screens.max { a, b in
            a.frame.intersection(rect).area < b.frame.intersection(rect).area
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

// MARK: - Helpers

private extension CGRect {
    var area: CGFloat { width * height }
}
