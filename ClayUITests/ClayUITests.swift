import XCTest

final class ClayUITests: XCTestCase {

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
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.click()

        XCTAssertTrue(app.otherElements["settings_panel"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toggle_notifications"].exists)
        XCTAssertTrue(app.buttons["toggle_colorblind"].exists)
        XCTAssertEqual(app.switches.count, 0)
    }
}
