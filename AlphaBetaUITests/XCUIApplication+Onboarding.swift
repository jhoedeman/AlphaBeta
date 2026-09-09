import XCTest

/// Shared onboarding-completion helper for UI tests. `-uiTesting` launches
/// give every test a blank SwiftData store, so onboarding is always the
/// first thing on screen — any test that needs to reach the main `TabView`
/// (Settings, Cards, Quiz) has to get through it first.
extension XCTestCase {
    @MainActor
    func completeOnboarding(_ app: XCUIApplication, selectingLanguageID id: Int, file: StaticString = #filePath, line: UInt = #line) {
        let getStarted = app.buttons["Get Started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5), file: file, line: line)
        getStarted.tap()

        // `.accessibilityElement(children: .combine)` over LanguageCell's two
        // Texts collapses it to a `staticTexts` element, not `otherElements`.
        let languageCell = app.staticTexts["languageCell-\(id)"]
        XCTAssertTrue(languageCell.waitForExistence(timeout: 5), file: file, line: line)
        languageCell.tap()
    }
}
