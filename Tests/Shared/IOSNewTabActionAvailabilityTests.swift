import Foundation
import Testing

struct IOSNewTabActionAvailabilityTests {
    @Test
    func newSheetAlwaysOrdersCreateTaskBeforeFocus() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let actions = try Self.functionSource(
            named: "private enum NewTabAction",
            endingAt: "private extension AppColorScheme",
            in: source
        )

        #expect(actions.contains("static let orderedActions: [NewTabAction] = [.createTask, .focus]"))
        #expect(actions.contains("return \"Create Task\""))
        #expect(actions.contains("return \"Focus\""))
        #expect(!actions.contains("case event"))
        #expect(!actions.contains("case sleep"))
    }

    @Test
    func newSheetRoutesOnlyCreateTaskAndFocus() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let routing = try Self.functionSource(
            named: "private func performNewTabAction",
            endingAt: "private func performanceInteraction",
            in: source
        )

        #expect(routing.contains("case .createTask:"))
        #expect(routing.contains("openNewTask()"))
        #expect(routing.contains("case .focus:"))
        #expect(routing.contains("openFocus()"))
    }

    @Test
    func selectingNewAlwaysPresentsTheTwoActionChooser() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let routing = try Self.functionSource(
            named: "private func openNewTabActionDestination",
            endingAt: "private func queueNewTabAction",
            in: source
        )

        #expect(routing.contains("isNewActionListPresented = true"))
        #expect(source.contains("actions: NewTabAction.orderedActions"))
    }

    @Test
    func focusOpensActiveControlsOrBuildsAStartPickerDeliberately() throws {
        let app = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let focus = try Self.functionSource(
            named: "private func openFocus",
            endingAt: "private func activeSessionKind",
            in: app
        )
        let picker = try Self.sourceFile("iOS/Screens/App/IOSFocusStartSheet.swift")

        #expect(focus.contains("modelContext.fetch(FetchDescriptor<FocusSession>())"))
        #expect(focus.contains("activeFocusControlPresentation = ActiveFocusControlPresentation("))
        #expect(focus.contains("IOSFocusStartPresentation.make("))
        #expect(picker.contains("FocusSessionStartDefaults.durationOptions"))
        #expect(picker.contains("FocusSessionSupport.startTaskFocus("))
        #expect(picker.contains("FocusSessionSupport.startTagFocus("))
        #expect(picker.contains("Button(action: onCreateTask)"))
        #expect(picker.contains("Text(\"Create Task\")"))
        #expect(picker.contains(".contentShape(Rectangle())"))
    }

    @Test
    func emptyFocusPickerDismissesBeforeOpeningTaskCreation() throws {
        let app = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        #expect(app.contains(
            ".sheet(item: $focusStartPresentation, onDismiss: performPendingFocusTaskCreation)"
        ))
        #expect(app.contains("onCreateTask: queueFocusTaskCreation"))
        #expect(app.contains("shouldCreateTaskAfterFocusDismissal = true"))
        #expect(app.contains("focusStartPresentation = nil"))
        #expect(app.contains("private func performPendingFocusTaskCreation()"))
        #expect(app.contains("openNewTask()"))
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
            "Toggle(\"Show Event and Emotion features\", isOn: $areEventEmotionActionsEnabled)"
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
        let events = try Self.functionSource(
            named: "private var events",
            endingAt: "private var emotionLogs",
            in: source
        )
        let emotionLogs = try Self.functionSource(
            named: "private var emotionLogs",
            endingAt: "private var notes",
            in: source
        )
        let sleepSessions = try Self.functionSource(
            named: "private var sleepSessions",
            endingAt: "private var awaySessions",
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
        #expect(source.contains(
            "areEventEmotionActionsEnabled ? dataSnapshot.emotionLogs : []"
        ))
        #expect(events.contains(
            "areEventEmotionActionsEnabled ? dataSnapshot.events : []"
        ))
        #expect(emotionLogs.contains("areEventEmotionActionsEnabled"))
        #expect(sleepSessions.contains(
            "includesSleepTimelineFilters ? dataSnapshot.sleepSessions : []"
        ))
        #expect(source.contains(
            ".onChange(of: isStatsSleepTabEnabled) { _, _ in\n                guard isActive else { return }\n                syncTimelineData()"
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
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
