import Testing
import XCTest

@Suite(.serialized)
struct RoutinaUITestsLaunchTests {
    @MainActor
    @Test
    func launch() {
        let app = XCUIApplication()
        app.launch()

        let screenshot = app.screenshot()
        #expect(!screenshot.pngRepresentation.isEmpty)
    }
}
