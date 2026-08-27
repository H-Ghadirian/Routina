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
    func homeRowTapOpensTaskDetail() {
        let app = makeApp()
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))

        let routineName = "UITest-\(UUID().uuidString.prefix(6))"

        let addRoutineButton = homeAddRoutineButton(in: app)
        #expect(addRoutineButton.waitForExistence(timeout: 10))
        addRoutineButton.tap()

        let nameField = app.textFields["Task name"]
        #expect(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(String(routineName))

        let saveButton = app.navigationBars.buttons["Save"]
        #expect(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", String(routineName))).firstMatch
        #expect(row.waitForExistence(timeout: 10))
        row.tap()

        let history = app.staticTexts["History"]
        let editButton = app.buttons["Edit"]
        #expect(history.waitForExistence(timeout: 10) || editButton.waitForExistence(timeout: 10))
    }

    @MainActor
    @Test
    func taskDetailAddDetailChevronOpensChooser() {
        let app = makeApp()
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))

        let routineName = "Add-detail-\(UUID().uuidString.prefix(6))"
        addRoutine(named: String(routineName), in: app)

        let row = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", String(routineName))
        ).firstMatch
        row.tap()

        let addDetailButton = app.buttons["Add a detail"]
        #expect(addDetailButton.waitForExistence(timeout: 10))
        addDetailButton.tap()

        let chooserNavigationBar = app.navigationBars["Add a detail"]
        #expect(chooserNavigationBar.waitForExistence(timeout: 10))
        #expect(app.buttons["History"].waitForExistence(timeout: 10))
    }

    @MainActor
    @Test
    func timelineTaskDetailAddDetailChevronOpensChooser() {
        let app = makeApp()
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))

        let routineName = "Timeline-detail-\(UUID().uuidString.prefix(6))"
        addRoutine(named: String(routineName), in: app)

        let homeRow = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", String(routineName))
        ).firstMatch
        homeRow.tap()

        let doneButton = app.buttons["Done"]
        #expect(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()
        #expect(app.buttons["Undo"].waitForExistence(timeout: 10))

        let timelineTab = app.buttons["Timeline"].firstMatch
        #expect(timelineTab.waitForExistence(timeout: 10))
        timelineTab.tap()

        let timelineRow = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", String(routineName))
        ).firstMatch
        #expect(timelineRow.waitForExistence(timeout: 10))
        timelineRow.tap()

        let addDetailButton = app.buttons["Add a detail"]
        #expect(addDetailButton.waitForExistence(timeout: 10))
        addDetailButton.tap()

        let chooserNavigationBar = app.navigationBars["Add a detail"]
        #expect(chooserNavigationBar.waitForExistence(timeout: 10))
        #expect(app.buttons["History"].waitForExistence(timeout: 10))
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

        let activeRoutinesTitle = app.staticTexts["Active repeating tasks"].firstMatch
        let archivedRoutinesTitle = app.staticTexts["Archived repeating tasks"].firstMatch
        let activeRoutinesCaption = app.staticTexts["1 paused excluded"].firstMatch
        let archivedRoutinesCaption = app.staticTexts["Paused and hidden from Home"].firstMatch

        #expect(reveal(activeRoutinesTitle, in: app))
        #expect(reveal(archivedRoutinesTitle, in: app))
        #expect(reveal(activeRoutinesCaption, in: app))
        #expect(reveal(archivedRoutinesCaption, in: app))
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
        let navigationButton = app.navigationBars.buttons["Add Task"].firstMatch
        if navigationButton.waitForExistence(timeout: 2) {
            return navigationButton
        }
        return app.buttons["New"].firstMatch
    }

    @MainActor
    private func addRoutine(named routineName: String, in app: XCUIApplication) {
        let addRoutineButton = homeAddRoutineButton(in: app)
        #expect(addRoutineButton.waitForExistence(timeout: 10))
        addRoutineButton.tap()

        let fullEditorNameField = app.textFields["Task name"]
        if fullEditorNameField.waitForExistence(timeout: 2) {
            fullEditorNameField.tap()
            fullEditorNameField.typeText(routineName)

            let saveButton = app.navigationBars.buttons["Save"]
            #expect(saveButton.waitForExistence(timeout: 10))
            saveButton.tap()
        } else {
            let quickAddField = app.textFields.firstMatch
            #expect(quickAddField.waitForExistence(timeout: 10))
            quickAddField.tap()
            quickAddField.typeText(routineName)

            let addButton = app.buttons["Add"].firstMatch
            #expect(addButton.waitForExistence(timeout: 10))
            addButton.tap()
        }

        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", routineName)).firstMatch
        #expect(row.waitForExistence(timeout: 10))
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 6
    ) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }
}
