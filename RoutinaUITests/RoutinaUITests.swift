import Foundation
import Testing
import XCTest

@Suite(.serialized)
struct RoutinaUITests {
    @MainActor
    @Test
    func appLaunches() {
        let app = XCUIApplication()
        app.launch()
        #expect(app.state == .runningForeground)
    }

    @MainActor
    @Test
    func homeRowTapOpensRoutineDetail() {
        let app = XCUIApplication()
        app.launch()

        let routineName = "UITest-\(UUID().uuidString.prefix(6))"

        app.navigationBars.buttons["Add Routine"].tap()

        let nameField = app.textFields["Routine name"]
        #expect(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(String(routineName))

        app.navigationBars.buttons["Save"].tap()

        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", String(routineName))).firstMatch
        #expect(row.waitForExistence(timeout: 5))
        row.tap()

        let routineLogs = app.staticTexts["Routine Logs"]
        let editButton = app.buttons["Edit"]
        #expect(routineLogs.waitForExistence(timeout: 5) || editButton.waitForExistence(timeout: 5))
    }
}
