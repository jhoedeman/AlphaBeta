import XCTest

/// Regression coverage for the palette-row dead-zone bug: a `Button` whose
/// label is a custom view (not plain `Text`) only accepts taps on its
/// rendered content unless given an explicit `.contentShape`. Note that
/// `element.tap()` is *not* sufficient to catch this — it dispatches at the
/// center of the element's own accessibility frame, which iOS already
/// reports as the tight hit-testable region (just the circle + text), so it
/// passes with or without `.contentShape`. A real user taps anywhere across
/// the visible row, so this test dispatches at an absolute screen point near
/// the row's trailing edge — well past a short label like "Sun of
/// Liberty" — to reproduce what actually broke in practice.
final class PaletteRowTapTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingPaletteRowTrailingEdgeSelectsThatPalette() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["Settings"].tap()

        let target = app.buttons["paletteRow-macedonian-flag"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.value as? String, "Not selected")

        // Tap near the row's trailing edge (screen-relative, not relative
        // to the button's own tight accessibility frame) — this is where
        // the checkmark would render if the row were active, and is well
        // past the "Sun of Liberty" label's rendered glyphs.
        let window = app.windows.firstMatch
        let rowTrailingEdge = window.coordinate(
            withNormalizedOffset: CGVector(
                dx: 0.85,
                dy: (target.frame.midY - window.frame.minY) / window.frame.height
            )
        )
        rowTrailingEdge.tap()

        XCTAssertEqual(target.value as? String, "Selected")
    }
}
