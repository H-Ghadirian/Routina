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
    func singleAvailableActionRoutesDirectlyWithoutPresentingChooser() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let routing = try Self.functionSource(
            named: "private func openNewTabActionDestination",
            endingAt: "private func queueNewTabAction",
            in: source
        )

        #expect(routing.contains("let actions = availableNewTabActions"))
        #expect(routing.contains("guard let action = actions.first else { return }"))
        #expect(routing.contains("guard actions.count > 1 else"))
        #expect(routing.contains("performNewTabAction(action)"))
        #expect(routing.contains("isNewActionListPresented = true"))
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
    func shakeSleepRechecksAvailabilityBeforeConfirmationAndStart() throws {
        let source = try Self.sourceFile("SharedCore/Views/SleepModeViews.swift")
        let confirmation = try Self.functionSource(
            named: "private func prepareSleepConfirmation",
            endingAt: "private func startSleep",
            in: source
        )
        let start = try Self.functionSource(
            named: "private func startSleep",
            endingAt: "private func clearShakeSleepStartPresentation",
            in: source
        )

        #expect(source.contains("appSettingAwayEnabled.rawValue"))
        #expect(source.contains("appSettingStatsSleepTabEnabled.rawValue"))
        #expect(source.contains("appSettingShakeToStartSleepEnabled.rawValue"))
        #expect(source.contains("if isShakeSleepStartAvailable"))
        #expect(confirmation.contains("guard isShakeSleepStartAvailable else"))
        #expect(start.contains("guard isShakeSleepStartAvailable else"))
        #expect(source.contains(".onChange(of: isShakeSleepStartAvailable)"))
        #expect(source.contains("static func dismantleUIViewController"))
        #expect(source.contains("uiViewController.resignFirstResponder()"))
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

    @Test
    func timelineTypeFiltersFollowFeatureAvailability() throws {
        let source = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")
        let visibleTypes = try Self.functionSource(
            named: "private var visibleTimelineFilterTypes",
            endingAt: "private var showsTypeFilterSection",
            in: source
        )
        let typeSection = try Self.functionSource(
            named: "private var showsTypeFilterSection",
            endingAt: "@ViewBuilder\n    private func timelineRow",
            in: source
        )

        #expect(source.contains("appSettingMacEventEmotionActionsEnabled.rawValue"))
        #expect(source.contains("appSettingStatsSleepTabEnabled.rawValue"))
        #expect(source.contains("isAwayEnabled && isStatsSleepTabEnabled"))
        #expect(visibleTypes.contains("includingEventEmotion: areEventEmotionActionsEnabled"))
        #expect(visibleTypes.contains("includingSleep: includesSleepTimelineFilters"))
        #expect(typeSection.contains("areEventEmotionActionsEnabled && (!events.isEmpty || !emotionLogs.isEmpty)"))
        #expect(typeSection.contains("includesSleepTimelineFilters && !sleepSessions.isEmpty"))
        #expect(source.contains("ForEach(visibleTimelineFilterTypes)"))
        #expect(source.contains("includesEventEmotion: areEventEmotionActionsEnabled"))
        #expect(source.contains("includesSleep: includesSleepTimelineFilters"))
        #expect(source.contains(".onChange(of: areEventEmotionActionsEnabled)"))
        #expect(source.contains(".onChange(of: isStatsSleepTabEnabled)"))
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
