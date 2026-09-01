//  OnboardingFlowUITests.swift — 4-step onboarding flow end-to-end via XCUIApplication
//  BoosterSimAppUITests (XCTest — this target's convention; the unit target uses Swift Testing)
//
//  Determinism: the app's '-uitest-reset-onboarding' launch argument (AppDelegate test seam)
//  forces first-launch state; completion then persists to UserDefaults for the no-reset relaunch.
//  Every step is skippable, so the flow needs no permission grants.

import XCTest

final class OnboardingFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-reset-onboarding"]
    }

    // MARK: - Identifier-backed queries

    private var onboardingWindow: XCUIElement { app.windows["Welcome to BoosterSim"] }

    private var stepTitle: XCUIElement { app.staticTexts["onboarding.stepTitle"].firstMatch }

    private var stepIndicator: XCUIElement { app.staticTexts["onboarding.stepIndicator"].firstMatch }

    private var skipButton: XCUIElement { app.buttons["onboarding.skip"].firstMatch }

    // MARK: - Helpers

    /// Waits for the animated step transition to settle on `title`, then asserts title + indicator.
    /// macOS SwiftUI StaticText exposes its content as `value` (label stays empty) — assert on value.
    private func assertStep(title: String, indicator: String, line: UInt = #line) {
        let valueMatches = NSPredicate(format: "value == %@", title)
        let settled = expectation(for: valueMatches, evaluatedWith: stepTitle)
        wait(for: [settled], timeout: 10)
        XCTAssertEqual(stepTitle.value as? String, title, "Step title", line: line)
        XCTAssertEqual(stepIndicator.value as? String, indicator, "Step indicator", line: line)
    }

    private func assertEventuallyGone(
        _ element: XCUIElement, _ message: String,
        timeout: TimeInterval = 5, line: UInt = #line
    ) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
        XCTAssertFalse(element.exists, message, line: line)
    }

    // MARK: - Flow

    @MainActor
    func testSkipPathWalksAllFourStepsAndCompletionPersists() throws {
        app.launch()

        // Reset launch: onboarding always appears, regardless of prior state
        XCTAssertTrue(onboardingWindow.waitForExistence(timeout: 15),
                      "Onboarding window should appear on reset launch")


        // Steps 1 → 4, each advanced via Skip
        assertStep(title: "Accessibility Access", indicator: "Step 1 of 4")
        skipButton.click()
        assertStep(title: "Select Xcode", indicator: "Step 2 of 4")
        skipButton.click()
        assertStep(title: "Screen Recording", indicator: "Step 3 of 4")
        skipButton.click()
        assertStep(title: "DerivedData Access", indicator: "Step 4 of 4")

        // Final skip completes onboarding and closes the window
        skipButton.click()
        assertEventuallyGone(onboardingWindow, "Onboarding window should close after the final skip")

        // Relaunch WITHOUT the reset argument — completion must persist
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertFalse(relaunched.windows["Welcome to BoosterSim"].waitForExistence(timeout: 5),
                       "Onboarding must not reappear after completion (no reset argument)")
    }
}
