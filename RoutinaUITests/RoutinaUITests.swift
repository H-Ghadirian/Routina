//  Created by ghadirianh on 07.03.25.
//

import XCTest

final class RoutinaUITests: XCTestCase {

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
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    func testHomeRowTapOpensRoutineDetail() throws {
        let app = XCUIApplication()
        app.launch()

        let routineName = "UITest-\(UUID().uuidString.prefix(6))"

        app.navigationBars.buttons["Add Routine"].tap()

        let nameField = app.textFields["Routine name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(String(routineName))

        app.navigationBars.buttons["Save"].tap()

        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", String(routineName))).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let routineLogs = app.staticTexts["Routine Logs"]
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(routineLogs.waitForExistence(timeout: 5) || editButton.waitForExistence(timeout: 5))
    }
}
