//  ScreenshotTests.swift — UI screenshot capture for CI visual regression
//  BoosterSimAppUITests

import XCTest

final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Launch Screenshots

    @MainActor
    func testLaunchScreen() throws {
        app.launch()

        // Wait for app to fully render
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "App window should appear")

        // Capture launch state
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "01-launch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Side Window Screenshots

    @MainActor
    func testSideWindowTabs() throws {
        app.launch()

        // Wait for side window to appear
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Side window should appear")

        // Screenshot: default tab state
        let defaultScreenshot = XCTAttachment(screenshot: app.screenshot())
        defaultScreenshot.name = "02-side-window-default"
        defaultScreenshot.lifetime = .keepAlways
        add(defaultScreenshot)

        // Try to find and click tab buttons (if they exist)
        let tabButtons = app.toolbars.buttons.allElementsBoundByIndex
        for (index, button) in tabButtons.enumerated() {
            if index >= 4 { break } // Max 4 tabs to screenshot
            button.click()
            // Small wait for tab transition
            Thread.sleep(forTimeInterval: 0.5)

            let tabScreenshot = XCTAttachment(screenshot: app.screenshot())
            tabScreenshot.name = "03-side-window-tab-\(index)"
            tabScreenshot.lifetime = .keepAlways
            add(tabScreenshot)
        }
    }

    // MARK: - Window Resize Screenshots

    @MainActor
    func testWindowResizeStates() throws {
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should appear")

        // Default size screenshot
        let normalScreenshot = XCTAttachment(screenshot: app.screenshot())
        normalScreenshot.name = "04-window-normal"
        normalScreenshot.lifetime = .keepAlways
        add(normalScreenshot)
    }

    // MARK: - Full Screen Screenshot (entire desktop)

    @MainActor
    func testFullScreenCapture() throws {
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Window should appear")

        // Capture entire screen (useful for verifying window positioning)
        let fullScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        fullScreenshot.name = "05-full-screen"
        fullScreenshot.lifetime = .keepAlways
        add(fullScreenshot)
    }
}
