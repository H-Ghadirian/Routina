import XCTest

@MainActor
final class RoutinaUIPerformanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 1_200
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
        let app = makeApp(seedProfile: "performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))

        warmUpTabs(in: app)

        measureInteraction {
            tapTab("Stats", in: app)
            tapTab("Settings", in: app)
            tapTab("Timeline", in: app)
            tapTab("Search", in: app)
            tapTab("Home", in: app)
        }
    }

    func testSeededHomeListScrollInteractionPerformance() {
        let app = makeApp(seedProfile: "performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(
            seedTask(named: "Seed Task 21", in: app).waitForExistence(timeout: 90),
            "The seeded Home todo did not finish loading"
        )

        app.swipeUp()
        app.swipeDown()

        measureInteraction {
            app.swipeUp()
            app.swipeDown()
        }
    }

    func testSeededStatsScrollInteractionPerformance() {
        let app = makeApp(seedProfile: "stats-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))

        openStats(in: app)
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 30))

        app.swipeUp()
        app.swipeUp()
        app.swipeDown()
        app.swipeDown()

        measureInteraction {
            app.swipeUp()
            app.swipeUp()
            app.swipeUp()
            app.swipeDown()
            app.swipeDown()
            app.swipeDown()
        }
    }

    func testSeededTimelineScrollInteractionPerformance() {
        let app = makeApp(seedProfile: "guided-review-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(
            seedTask(named: "Guided Review Task 020", in: app).waitForExistence(timeout: 90),
            "The long-history test store did not finish loading"
        )

        tapTab("Timeline", in: app)
        XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 10))
        app.swipeUp()
        app.swipeDown()

        measureInteraction {
            app.swipeUp()
            app.swipeUp()
            app.swipeUp()
            app.swipeDown()
            app.swipeDown()
            app.swipeDown()
        }
    }

    func testSeededHomeSearchAndTaskDetailListTraversal() {
        let app = makeApp(seedProfile: "guided-review-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(
            seedTask(named: "Guided Review Task 020", in: app).waitForExistence(timeout: 90),
            "The long-history traversal store did not finish loading"
        )

        let firstTask = seedTask(named: "Guided Review Task 020", in: app)
        XCTAssertTrue(firstTask.waitForExistence(timeout: 10))
        firstTask.tap()
        XCTAssertTrue(taskDetailLoaded(in: app))
        scrollToBothEdges(in: app, swipeCount: 16)

        tapTab("Home", in: app)
        XCTAssertTrue(app.navigationBars["Todos"].waitForExistence(timeout: 10))
        selectAllHomeTasks(in: app)
        scrollToBothEdges(in: app, swipeCount: 60)

        tapTab("New", in: app)
        XCTAssertTrue(app.navigationBars["New Task"].waitForExistence(timeout: 10))
        scrollToBothEdges(in: app, swipeCount: 4)
        let newTaskCancel = app.navigationBars.buttons["Cancel"].firstMatch
        XCTAssertTrue(newTaskCancel.waitForExistence(timeout: 10))
        newTaskCancel.tap()

        tapTab("Search", in: app)
        scrollToBothEdges(in: app, swipeCount: 40)
    }

    func testSeededTimelineListEdgeTraversal() {
        let app = makeApp(seedProfile: "guided-review-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(
            seedTask(named: "Guided Review Task 020", in: app).waitForExistence(timeout: 90),
            "The long-history Timeline store did not finish loading"
        )

        tapTab("Timeline", in: app)
        XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 10))
        scrollToBothEdges(in: app, swipeCount: 140)
        openTimelineFilterSheetAndScroll(in: app)
    }

    func testSeededMoreStatsAndSettingsListTraversal() {
        let app = makeApp(seedProfile: "guided-review-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(
            seedTask(named: "Guided Review Task 020", in: app).waitForExistence(timeout: 90),
            "The long-history More store did not finish loading"
        )

        tapTab("More", in: app)
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 10))
        scrollToBothEdges(in: app, swipeCount: 4)
        visitMoreDestination(named: "Help me choose", in: app, swipeCount: 4)
        visitMoreDestination(named: "Add missing Pressure data", in: app, swipeCount: 4)
        visitMoreDestination(named: "Add missing Thinking needed data", in: app, swipeCount: 4)
        visitMoreDestination(named: "Add missing time estimates", in: app, swipeCount: 4)
        visitMoreDestination(named: "Review Importance", in: app, swipeCount: 4)
        visitMoreDestination(named: "Review Urgency", in: app, swipeCount: 4)
        visitMoreDestination(named: "Stats", in: app, swipeCount: 12)
        visitMoreDestination(named: "Settings", in: app, swipeCount: 16)
    }

    func testSeededTaskDetailNavigationInteractionPerformance() {
        let app = makeApp(seedProfile: "performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let row = seedTask(named: "Seed Task 21", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 90))
        row.tap()
        XCTAssertTrue(taskDetailLoaded(in: app))
        backToHome(in: app)

        measureInteraction {
            let measuredRow = seedTask(named: "Seed Task 21", in: app)
            XCTAssertTrue(measuredRow.waitForExistence(timeout: 90))
            measuredRow.tap()
            XCTAssertTrue(taskDetailLoaded(in: app))
            backToHome(in: app)
        }
    }

    func testSeededGuidedReviewTaskDetailRoundTripPerformance() {
        let app = makeApp(seedProfile: "guided-review-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(
            seedTask(named: "Guided Review Task 020", in: app).waitForExistence(timeout: 90),
            "The large seeded review store did not finish loading"
        )

        openImportanceReview(in: app)
        openGuidedReviewTaskDetails(in: app)
        returnToGuidedReview(in: app)

        measureInteraction {
            openImportanceReview(in: app)
            openGuidedReviewTaskDetails(in: app)
            returnToGuidedReview(in: app)
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
        let app = makeApp(seedProfile: "performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(seedTask(named: "Seed Task 21", in: app).waitForExistence(timeout: 90))

        openAndCloseFilterSheet(in: app)
        measureInteraction {
            openAndCloseFilterSheet(in: app)
        }
    }

    func testSeededFilterTagTogglePerformance() {
        let app = makeApp(seedProfile: "performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(seedTask(named: "Seed Task 21", in: app).waitForExistence(timeout: 90))

        openFilterSheet(in: app)
        toggleFilterChip(containing: "#Health", in: app)
        toggleFilterChip(containing: "#Health", in: app)
        closeFilterSheet(in: app)

        measureInteraction {
            openFilterSheet(in: app)
            toggleFilterChip(containing: "#Health", in: app)
            toggleFilterChip(containing: "#Health", in: app)
            closeFilterSheet(in: app)
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

    func testLargeSeededRapidNoMatchSearchPerformance() {
        let app = makeApp(seedProfile: "search-performance")
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(
            seedTask(named: "Search Stress Task", in: app).waitForExistence(timeout: 180),
            "The large Search performance store did not finish loading"
        )

        XCTContext.runActivity(named: "Rapid long no-match Search interaction") { activity in
            let startTime = ProcessInfo.processInfo.systemUptime
            tapTab("Search", in: app)
            let searchField = app.searchFields.firstMatch
            XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Missing Search field")
            var cycleDurations: [TimeInterval] = []
            for cycle in 1...4 {
                let cycleStartTime = ProcessInfo.processInfo.systemUptime
                searchField.tap()
                XCTAssertTrue(
                    app.keyboards.firstMatch.waitForExistence(timeout: 5),
                    "The keyboard did not open for Search cycle \(cycle)"
                )
                searchField.typeText(
                    "this deliberately long query cannot match seeded task \(cycle) 987654321"
                )

                XCTAssertTrue(
                    app.staticTexts["No matching todos"].waitForExistence(timeout: 30),
                    "Search cycle \(cycle) did not settle on the expected no-match result"
                )

                let clearButton = searchField.buttons.firstMatch
                XCTAssertTrue(
                    clearButton.waitForExistence(timeout: 5),
                    "Search cycle \(cycle) did not expose its clear button"
                )
                clearButton.tap()
                XCTAssertTrue(
                    seedTask(named: "Search Stress Task", in: app).waitForExistence(timeout: 30),
                    "Search cycle \(cycle) did not restore the full task presentation"
                )

                let closeSearchButton = app.buttons["Close"].firstMatch
                XCTAssertTrue(
                    closeSearchButton.waitForExistence(timeout: 5),
                    "Search cycle \(cycle) did not expose the native Close action"
                )
                closeSearchButton.tap()
                XCTAssertTrue(
                    waitForKeyboardToDisappear(in: app, timeout: 5),
                    "The keyboard did not close after Search cycle \(cycle)"
                )
                cycleDurations.append(ProcessInfo.processInfo.systemUptime - cycleStartTime)
            }
            let duration = ProcessInfo.processInfo.systemUptime - startTime
            activity.add(
                XCTAttachment(
                    string: String(
                        format: "Search interaction duration: %.3f seconds; cycles: %@",
                        duration,
                        cycleDurations.map { String(format: "%.3f", $0) }.joined(separator: ", ")
                    )
                )
            )
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

    private func makeApp(seedProfile: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let runID = UUID().uuidString.lowercased()
        app.launchEnvironment["ROUTINA_UI_TEST_MODE"] = "1"
        app.launchEnvironment["ROUTINA_SANDBOX"] = "1"
        app.launchEnvironment["ROUTINA_UNLOCK_ALL_TASKS"] = "1"
        app.launchEnvironment["ROUTINA_STORE_FILENAME"] = "RoutinaModel-UIPerf-\(runID).sqlite"
        app.launchEnvironment["ROUTINA_USER_DEFAULTS_SUITE"] = "app.ui-perf.\(runID)"
        if let seedProfile {
            app.launchEnvironment["ROUTINA_UI_TEST_SEED_PROFILE"] = seedProfile
        }
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
        tapTab("Timeline", in: app)
        tapTab("Search", in: app)
        tapTab("Home", in: app)
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing \(label) tab")
        tab.tap()
    }

    private func waitForKeyboardToDisappear(
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let keyboard = app.keyboards.firstMatch
        return waitForElementToBecomeNonHittable(keyboard, timeout: timeout)
    }

    private func waitForElementToBecomeNonHittable(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while element.exists,
              element.isHittable,
              ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !element.exists || !element.isHittable
    }

    private func openStats(in app: XCUIApplication) {
        let directTab = app.tabBars.buttons["Stats"].firstMatch
        if directTab.exists {
            directTab.tap()
            return
        }

        tapTab("More", in: app)
        let statsButton = app.buttons.containing(
            NSPredicate(format: "label BEGINSWITH %@", "Stats")
        ).firstMatch
        XCTAssertTrue(statsButton.waitForExistence(timeout: 10), "Missing Stats destination")
        statsButton.tap()
    }

    private func homeAddTaskButton(in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.buttons["Add Task"].firstMatch
    }

    private func seedTask(named taskName: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", taskName)).firstMatch
    }

    private func taskDetailLoaded(in app: XCUIApplication) -> Bool {
        app.staticTexts["History"].waitForExistence(timeout: 10)
            || app.buttons["Edit"].waitForExistence(timeout: 10)
    }

    private func backToHome(in app: XCUIApplication) {
        let homeBackButton = app.navigationBars.buttons["Routina"].firstMatch
        XCTAssertTrue(homeBackButton.waitForExistence(timeout: 10))
        homeBackButton.tap()
        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
    }

    private func openImportanceReview(in app: XCUIApplication) {
        tapTab("More", in: app)

        let reviewButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Review Importance")
        ).firstMatch
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 10), "Missing Review Importance")
        reviewButton.tap()

        XCTAssertTrue(app.navigationBars["Review Importance"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Guided Review Task 001"].waitForExistence(timeout: 10))
    }

    private func openGuidedReviewTaskDetails(in app: XCUIApplication) {
        let detailsButton = app.buttons["Check task details"].firstMatch
        XCTAssertTrue(detailsButton.waitForExistence(timeout: 10))
        detailsButton.tap()
        XCTAssertTrue(taskDetailLoaded(in: app))
    }

    private func returnToGuidedReview(in app: XCUIApplication) {
        tapTab("More", in: app)
        XCTAssertTrue(app.navigationBars["Review Importance"].waitForExistence(timeout: 10))
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
        openFilterSheet(in: app)
        closeFilterSheet(in: app)
    }

    private func selectAllHomeTasks(in app: XCUIApplication) {
        openFilterSheet(in: app)

        let allTasksButton = app.buttons["All"].firstMatch
        XCTAssertTrue(allTasksButton.waitForExistence(timeout: 10), "Missing All task-type filter")
        allTasksButton.tap()

        let doneButton = app.navigationBars["Filters"].buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        XCTAssertTrue(app.navigationBars["All"].waitForExistence(timeout: 10))
    }

    private func openFilterSheet(in app: XCUIApplication) {
        let filtersButton = app.buttons["Filters"].firstMatch
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 10))
        filtersButton.tap()

        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 10))
    }

    private func closeFilterSheet(in app: XCUIApplication) {
        let doneButton = app.navigationBars["Filters"].buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        XCTAssertTrue(homeAddTaskButton(in: app).waitForExistence(timeout: 10))
    }

    private func openTimelineFilterSheetAndScroll(in app: XCUIApplication) {
        let filtersButton = app.buttons["Filters"].firstMatch
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 10))
        filtersButton.tap()
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 10))
        scrollToBothEdges(in: app, swipeCount: 8)

        let doneButton = app.navigationBars["Filters"].buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()
        XCTAssertTrue(app.navigationBars["Timeline"].waitForExistence(timeout: 10))
    }

    private func visitMoreDestination(
        named name: String,
        in app: XCUIApplication,
        swipeCount: Int = 12
    ) {
        let destination = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", name)
        ).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Missing \(name) destination")
        destination.tap()
        scrollToBothEdges(in: app, swipeCount: swipeCount)

        tapTab("More", in: app)
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 10))
    }

    private func scrollToBothEdges(in app: XCUIApplication, swipeCount: Int) {
        for _ in 0..<swipeCount {
            app.swipeUp()
        }
        for _ in 0..<swipeCount {
            app.swipeDown()
        }
    }

    private func toggleFilterChip(containing labelPart: String, in app: XCUIApplication) {
        let chip = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", labelPart)
        ).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Missing filter chip containing \(labelPart)")
        chip.tap()
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
