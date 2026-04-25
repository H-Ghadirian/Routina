import XCTest

@MainActor
final class RoutinaUIPerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchPerformance() {
        let app = makeApp()
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(
            metrics: [XCTApplicationLaunchMetric()],
            options: options,
            block: {
                app.launch()
            }
        )
    }

    func testTabSwitchingInteractionPerformance() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        warmUpTabs(in: app)

        measureInteraction {
            tapTab("Stats", in: app)
            tapTab("Settings", in: app)
            tapTab("Dones", in: app)
            tapTab("Search", in: app)
            tapTab("Home", in: app)
        }
    }

    func testAddTaskSheetPresentationPerformance() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        openAndCloseAddTaskSheet(in: app)
        measureInteraction {
            openAndCloseAddTaskSheet(in: app)
        }
    }

    func testFilterSheetPresentationPerformance() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        openAndCloseFilterSheet(in: app)
        measureInteraction {
            openAndCloseFilterSheet(in: app)
        }
    }

    func testSearchTabActivationPerformance() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        tapTab("Search", in: app)
        tapTab("Home", in: app)

        measureInteraction {
            tapTab("Search", in: app)
            tapTab("Home", in: app)
        }
    }

    func testAddRoutineSaveFlowPerformance() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        measureInteraction {
            addRoutine(in: app)
        }
    }

    func testTaskDetailNavigationPerformance() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        let routineName = "PerfDetail-\(UUID().uuidString.prefix(6))"
        addRoutine(named: String(routineName), in: app)

        let row = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", String(routineName))
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        openAndCloseTaskDetail(forRow: row, in: app)
        measureInteraction {
            openAndCloseTaskDetail(forRow: row, in: app)
        }
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        let runID = UUID().uuidString.lowercased()
        app.launchEnvironment["ROUTINA_UI_TEST_MODE"] = "1"
        app.launchEnvironment["ROUTINA_SANDBOX"] = "1"
        app.launchEnvironment["ROUTINA_STORE_FILENAME"] = "RoutinaModel-UIPerf-\(runID).sqlite"
        app.launchEnvironment["ROUTINA_USER_DEFAULTS_SUITE"] = "app.ui-perf.\(runID)"
        return app
    }

    private func measureInteraction(_ block: () -> Void) {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(),
                XCTMemoryMetric()
            ],
            options: options,
            block: block
        )
    }

    private func warmUpTabs(in app: XCUIApplication) {
        tapTab("Stats", in: app)
        tapTab("Settings", in: app)
        tapTab("Dones", in: app)
        tapTab("Search", in: app)
        tapTab("Home", in: app)
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing \(label) tab")
        tab.tap()
    }

    private func homeAddTaskButton(in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.buttons["Add Task"].firstMatch
    }

    private func openAndCloseAddTaskSheet(in app: XCUIApplication) {
        let addTaskButton = homeAddTaskButton(in: app)
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: 10))
        addTaskButton.tap()

        let cancelButton = app.navigationBars.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        cancelButton.tap()

        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
    }

    private func openAndCloseFilterSheet(in app: XCUIApplication) {
        let filtersButton = app.buttons["Filters"].firstMatch
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 10))
        filtersButton.tap()

        let doneButton = app.navigationBars["Filters"].buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
    }

    private func addRoutine(in app: XCUIApplication) {
        addRoutine(named: "Perf-\(UUID().uuidString.prefix(6))", in: app)
    }

    private func addRoutine(named routineName: String, in app: XCUIApplication) {
        let addTaskButton = homeAddTaskButton(in: app)
        XCTAssertTrue(addTaskButton.waitForExistence(timeout: 10))
        addTaskButton.tap()

        let nameField = app.textFields["Task name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(routineName)

        let saveButton = app.navigationBars.buttons["Save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
        saveButton.tap()

        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
    }

    private func openAndCloseTaskDetail(forRow row: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let backButton = app.navigationBars.buttons["Routina"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        backButton.tap()

        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
    }
}
