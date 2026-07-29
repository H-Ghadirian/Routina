import Foundation
import Testing

struct IOSNewTabActionAvailabilityTests {
    @Test
    func newSheetFiltersEveryExperimentBackedAction() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let availability = try Self.functionSource(
            named: "private var availableNewTabActions",
            endingAt: "private var newActionListSheetHeight",
            in: source
        )

        #expect(availability.contains("action != .event || areEventEmotionActionsEnabled"))
        #expect(availability.contains("action != .emotion || areEventEmotionActionsEnabled"))
        #expect(availability.contains("action != .goal || isGoalsTabEnabled"))
        #expect(availability.contains("action != .sleep || isNewSheetSleepActionEnabled"))
    }

    @Test
    func directActionRoutingRepeatsExperimentGuards() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let routing = try Self.functionSource(
            named: "private func performNewTabAction",
            endingAt: "private func openNewTask",
            in: source
        )

        #expect(routing.contains("guard areEventEmotionActionsEnabled else { return }"))
        #expect(routing.contains("guard isGoalsTabEnabled else { return }"))
        #expect(routing.contains("guard isNewSheetSleepActionEnabled else { return }"))
    }

    @Test
    func sleepRequiresBetaAvailabilityAndNewSheetPreference() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let sleepAvailability = try Self.functionSource(
            named: "private var isNewSheetSleepActionEnabled",
            endingAt: "private var availableNewTabActions",
            in: source
        )

        #expect(sleepAvailability.contains("isAwayEnabled"))
        #expect(sleepAvailability.contains("isSleepExperimentEnabled"))
        #expect(sleepAvailability.contains("isSleepNewSheetEnabled"))
    }

    @Test
    func iosBetaExperimentsExposeEventEmotionGate() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Settings/SettingsDataSupportDetailViews.swift"
        )

        #expect(source.contains(
            "Toggle(\"Show Event and Emotion actions\", isOn: $areEventEmotionActionsEnabled)"
        ))
    }

    private static func functionSource(
        named startMarker: String,
        endingAt endMarker: String,
        in source: String
    ) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(
            source.range(
                of: endMarker,
                range: start.upperBound..<source.endIndex
            )
        )
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
