import Foundation
import Testing
import XCTest

@Suite(.serialized)
struct RoutinaUITestsLaunchTests {
    @MainActor
    @Test
    func launch() {
        let app = XCUIApplication()
        let runID = UUID().uuidString.lowercased()
        app.launchEnvironment["ROUTINA_UI_TEST_MODE"] = "1"
        app.launchEnvironment["ROUTINA_SANDBOX"] = "1"
        app.launchEnvironment["ROUTINA_STORE_FILENAME"] = "RoutinaModel-UITests-\(runID).sqlite"
        app.launchEnvironment["ROUTINA_USER_DEFAULTS_SUITE"] = "app.ui-tests.\(runID)"
        app.launch()
        #expect(app.wait(for: .runningForeground, timeout: 10))

        let screenshot = app.screenshot()
        #expect(!screenshot.pngRepresentation.isEmpty)
    }
}
