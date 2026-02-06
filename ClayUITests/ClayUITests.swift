import XCTest

final class ClayUITests: XCTestCase {

    private func anyElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testSettingsUsesCustomControls() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsButton = app.buttons["nav_settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        XCTAssertTrue(anyElement("settings_panel", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Offline cap"].exists)
        XCTAssertEqual(app.switches.count, 0)
    }

    @MainActor
    func testBaseFocusModeHidesChrome() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(anyElement("sidebar", in: app).waitForExistence(timeout: 5))

        let focusButton = app.buttons["base_focus_toggle"]
        XCTAssertTrue(focusButton.waitForExistence(timeout: 5))
        focusButton.click()

        XCTAssertTrue(app.buttons["base_focus_exit"].waitForExistence(timeout: 5))
        XCTAssertFalse(anyElement("sidebar", in: app).exists)
        XCTAssertFalse(anyElement("right_panel", in: app).exists)
        XCTAssertFalse(anyElement("guidance_banner", in: app).exists)
        XCTAssertFalse(anyElement("bottom_ticker", in: app).exists)

        app.buttons["base_focus_exit"].click()

        XCTAssertTrue(anyElement("sidebar", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("right_panel", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("guidance_banner", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("bottom_ticker", in: app).waitForExistence(timeout: 5))
    }
}
