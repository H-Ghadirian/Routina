import Foundation
import Testing
import XCTest

@Suite(.serialized)
struct RoutinaUITests {
    @MainActor
    @Test
    func appLaunches() {
        let app = makeApp()
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))
        #expect(homeAddRoutineButton(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    @Test
    func homeRowTapOpensRoutineDetail() {
        let app = makeApp()
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))

        let routineName = "UITest-\(UUID().uuidString.prefix(6))"

        let addRoutineButton = homeAddRoutineButton(in: app)
        #expect(addRoutineButton.waitForExistence(timeout: 10))
        addRoutineButton.tap()

        let nameField = app.textFields["Routine name"]
        #expect(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(String(routineName))

        let saveButton = app.navigationBars.buttons["Save"]
        #expect(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", String(routineName))).firstMatch
        #expect(row.waitForExistence(timeout: 10))
        row.tap()

        let routineLogs = app.staticTexts["Routine Logs"]
        let editButton = app.buttons["Edit"]
        #expect(routineLogs.waitForExistence(timeout: 10) || editButton.waitForExistence(timeout: 10))
    }

    @MainActor
    @Test
    func statsShowsActiveAndArchivedRoutineCounts() {
        let app = makeApp()
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))

        let activeRoutineName = "Active-\(UUID().uuidString.prefix(6))"
        let archivedRoutineName = "Archived-\(UUID().uuidString.prefix(6))"

        addRoutine(named: String(activeRoutineName), in: app)
        addRoutine(named: String(archivedRoutineName), in: app)

        let archivedRow = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", String(archivedRoutineName))
        ).firstMatch
        #expect(archivedRow.waitForExistence(timeout: 10))
        archivedRow.tap()

        let pauseButton = app.buttons["Pause Routine"]
        #expect(pauseButton.waitForExistence(timeout: 10))
        pauseButton.tap()

        let homeBackButton = app.navigationBars.buttons["Routina"].firstMatch
        #expect(homeBackButton.waitForExistence(timeout: 10))
        homeBackButton.tap()

        let statsTab = app.tabBars.buttons["Stats"].firstMatch
        #expect(statsTab.waitForExistence(timeout: 10))
        statsTab.tap()

        #expect(app.staticTexts["1 active routine"].waitForExistence(timeout: 10))
        #expect(app.staticTexts["1 archived routine"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        let runID = UUID().uuidString.lowercased()
        app.launchEnvironment["ROUTINA_UI_TEST_MODE"] = "1"
        app.launchEnvironment["ROUTINA_SANDBOX"] = "1"
        app.launchEnvironment["ROUTINA_STORE_FILENAME"] = "RoutinaModel-UITests-\(runID).sqlite"
        app.launchEnvironment["ROUTINA_USER_DEFAULTS_SUITE"] = "app.ui-tests.\(runID)"
        return app
    }

    @MainActor
    private func homeAddRoutineButton(in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.buttons["Add Routine"].firstMatch
    }

    @MainActor
    private func addRoutine(named routineName: String, in app: XCUIApplication) {
        let addRoutineButton = homeAddRoutineButton(in: app)
        #expect(addRoutineButton.waitForExistence(timeout: 10))
        addRoutineButton.tap()

        let nameField = app.textFields["Routine name"]
        #expect(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(routineName)

        let saveButton = app.navigationBars.buttons["Save"]
        #expect(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", routineName)).firstMatch
        #expect(row.waitForExistence(timeout: 10))
    }
}
