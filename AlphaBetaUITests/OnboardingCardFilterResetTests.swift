import XCTest

/// Regression coverage for a bug reported after shipping onboarding: a
/// stale, narrowed card filter (e.g. left over from earlier browsing, or a
/// DEBUG onboarding replay) used to carry straight into the first card
/// onboarding shows, landing on whatever that filter's first item happened
/// to be (a "combinations" entry) instead of the manifest's natural,
/// unfiltered order (capital Alpha, for Greek). `OnboardingView.complete`
/// now resets card filters/shuffle before completing.
final class OnboardingCardFilterResetTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testReplayingOnboardingResetsANarrowedCardFilter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        completeOnboarding(app, selectingLanguageID: 0)
        assertShowingAlphaCard(app)

        // Narrow the filter down to Combinations only — the stale state
        // that used to leak into a subsequent onboarding replay.
        app.staticTexts["filterPill-capitals"].tap()
        app.staticTexts["filterPill-lowercase"].tap()
        app.staticTexts["filterPill-diphthongs"].tap()
        XCTAssertTrue(app.staticTexts["1 / 7"].waitForExistence(timeout: 5))

        app.buttons["Settings"].tap()
        app.swipeUp()
        let replayButton = app.buttons["Replay Onboarding"]
        XCTAssertTrue(replayButton.waitForExistence(timeout: 5))
        replayButton.tap()

        completeOnboarding(app, selectingLanguageID: 0)

        // Bug reproduction: without the reset, this would land on a
        // "combinations" entry (e.g. Greek's τζ) instead of Alpha.
        assertShowingAlphaCard(app)
    }

    @MainActor
    private func assertShowingAlphaCard(_ app: XCUIApplication) {
        // CardFaceView uses `.accessibilityElement(children: .ignore)`,
        // which surfaces as `otherElements` (unlike LanguageCell's
        // `.combine`, which collapses to `staticTexts`).
        let alphaCard = app.otherElements["Alpha, capitals"]
        if !alphaCard.waitForExistence(timeout: 5) {
            print("=== ACCESSIBILITY TREE DUMP (Alpha, capitals not found) ===")
            print(app.debugDescription)
        }
        XCTAssertTrue(alphaCard.exists)
    }
}
