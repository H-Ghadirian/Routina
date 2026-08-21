import Foundation
import Testing

struct TaskDetailPlatformActionParityTests {
    @Test
    func iosOneDayRoutineActionsOmitTheMacAbsentOngoingStart() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let routineActions = try Self.sourceSection(
            startingAt: "struct TaskDetailRoutinePrimaryActionSection",
            endingAt: "struct TaskDetailPrimaryActionButton",
            in: source
        )

        #expect(!routineActions.contains("Start ongoing"))
        #expect(!routineActions.contains("startOngoingButton"))
        #expect(!routineActions.contains(".startOngoingTapped"))
        #expect(routineActions.contains("routineActionsMenu"))
        #expect(routineActions.contains("More routine actions"))
        #expect(routineActions.contains("Not today — hide until tomorrow"))
    }

    @Test
    func iosTaskDetailsGroupMaintenanceActionsInNavigationOverflow() throws {
        let toolbarSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailToolbarContent.swift"
        )
        let actionControlsSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let editSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailEditRoutineContentPlatform.swift"
        )

        #expect(toolbarSource.contains("Menu {"))
        #expect(toolbarSource.contains("RoutinaDeepLinkShareActions("))
        #expect(toolbarSource.contains("store.send(.cancelTodo)"))
        #expect(toolbarSource.contains(".disabled(store.isCancelTodoButtonDisabled)"))
        #expect(toolbarSource.contains("Button(role: .destructive)"))
        #expect(toolbarSource.contains("store.send(.setDeleteConfirmation(true))"))
        #expect(toolbarSource.contains("Text(\"⋮\")"))
        #expect(!toolbarSource.contains("ellipsis.vertical"))
        #expect(toolbarSource.contains(".font(.system(size: 22, weight: .bold, design: .rounded))"))
        #expect(toolbarSource.contains(".frame(width: 24, height: 24)"))
        #expect(toolbarSource.contains(".contentShape(Rectangle())"))
        #expect(toolbarSource.contains(".accessibilityLabel(\"More task actions\")"))
        #expect(toolbarSource.contains("showsCollapsedTaskTitle"))
        #expect(toolbarSource.contains("collapsedTaskTitleLabel"))
        #expect(toolbarSource.contains("Text(RoutineTask.trimmedName(store.task.name) ?? \"Task\")"))
        #expect(toolbarSource.contains(".lineLimit(1)"))
        #expect(!toolbarSource.contains("Text(store.routineEmoji)"))
        #expect(!toolbarSource.contains(".frame(maxWidth: 150)"))
        #expect(toolbarSource.contains(".minimumScaleFactor(0.75)"))
        #expect(toolbarSource.contains(".allowsTightening(true)"))
        #expect(!toolbarSource.contains("RoutinaDeepLinkShareMenu("))
        #expect(!actionControlsSource.contains("TaskDetailCancelTodoButton"))
        #expect(!editSource.contains("onDelete:"))
    }

    @Test
    func iosTaskDetailShowsItsToolbarTitleOnlyAfterTheHeaderTitleScrollsAway() throws {
        let detailSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let headerSource = try Self.sourceFile(
            "SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift"
        )

        #expect(detailSource.contains("overlayPreferenceValue(TaskDetailHeaderTitleBoundsPreferenceKey.self)"))
        #expect(detailSource.contains("TaskDetailCollapsedTitlePresentation.shouldShow("))
        #expect(detailSource.contains("showsCollapsedTaskTitle: showsCollapsedTaskTitle"))
        #expect(headerSource.contains("key: TaskDetailHeaderTitleBoundsPreferenceKey.self"))
        #expect(headerSource.contains("value: .bounds"))
    }

    @Test
    func multiDayPrimaryActionKeepsStartAndStopLifecycle() throws {
        let source = try Self.sourceFile(
            "SharedCore/Features/TaskDetail/TaskDetailFeature+Presentation.swift"
        )

        #expect(source.contains("if task.isMultiDayRoutine"))
        #expect(source.contains("return .startOngoingTapped"))
        #expect(source.contains("return .finishOngoingTapped"))
        #expect(source.contains("return \"play.circle.fill\""))
        #expect(source.contains("return \"stop.circle.fill\""))
    }

    @Test
    func macFullDetailGroupsSecondaryTaskActionsInAnOverflowMenu() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailToolbarContent.swift"
        )
        let overflowMenu = try Self.sourceSection(
            startingAt: "private var taskLifecycleActionsMenu",
            endingAt: "private var showsFullDetailActions: Bool",
            in: source
        )

        #expect(!overflowMenu.contains("Menu {"))
        #expect(overflowMenu.contains("TaskDetailOverflowMenuPresenter("))
        #expect(overflowMenu.contains("taskLifecycleActionsMenuRequestID &+= 1"))
        #expect(overflowMenu.contains("store.send(.resumeTapped)"))
        #expect(overflowMenu.contains("store.send(.pauseTapped)"))
        #expect(overflowMenu.contains("isPauseUntilPresented = true"))
        #expect(overflowMenu.contains("systemImage: \"clock.arrow.circlepath\""))
        #expect(overflowMenu.contains("store.send(.cancelTodo)"))
        #expect(overflowMenu.contains("store.send(.setDeleteConfirmation(true))"))
        #expect(overflowMenu.contains("role: .destructive"))
        #expect(overflowMenu.contains("Text(\"⋮\")"))
        #expect(overflowMenu.contains("isTaskLifecycleActionsMenuPresented"))
        #expect(overflowMenu.contains("toolbarIconChrome(isActive: isTaskLifecycleActionsMenuPresented)"))
        #expect(!overflowMenu.contains("Circle()"))
        #expect(source.contains("menu.popUp("))
        #expect(source.contains("NSColor.systemRed"))
    }

    @Test
    func iosAddMoreDetailsSectionIsLastForTodosAndRoutines() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let todoContent = try Self.sourceSection(
            startingAt: "private var todoDetailContent",
            endingAt: "private var taskDetailContent",
            in: source
        )
        let routineContent = try Self.sourceSection(
            startingAt: "private var taskDetailContent",
            endingAt: "private var focusSessionSection",
            in: source
        )

        try assertOptionalActionsAreLast(in: todoContent)
        try assertOptionalActionsAreLast(in: routineContent)
    }

    @Test
    func iosTodoCompletionPrecedesSecondaryCalendarWithoutAnEmptyOuterCard() throws {
        let detailSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let actionControlsSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let todoContent = try Self.sourceSection(
            startingAt: "private var todoDetailContent",
            endingAt: "private var taskDetailContent",
            in: detailSource
        )
        let todoActions = try Self.sourceSection(
            startingAt: "struct TaskDetailTodoPrimaryActionSection",
            endingAt: "struct TaskDetailRoutinePrimaryActionSection",
            in: actionControlsSource
        )

        let header = try #require(todoContent.range(of: "todoHeaderSection"))
        let completion = try #require(todoContent.range(of: "TaskDetailTodoPrimaryActionSection("))
        let calendar = try #require(todoContent.range(of: "calendarSection"))
        #expect(header.lowerBound < completion.lowerBound)
        #expect(completion.lowerBound < calendar.lowerBound)

        #expect(todoActions.contains("if hasSupportingContext"))
        #expect(todoActions.contains("else {\n                TaskDetailPrimaryActionButton(store: store)"))
        #expect(todoActions.contains(".detailCardStyle()"))
    }

    @Test
    func taskDetailPrimaryCompletionActionsShareSemanticTintAcrossPlatforms() throws {
        let iosSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let macSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailToolbarContent.swift"
        )

        #expect(iosSource.contains("TaskDetailPresentation.completionActionTint("))
        #expect(macSource.contains("TaskDetailPresentation.completionActionTint("))
        #expect(iosSource.contains(".tint("))
    }

    @Test
    func iosAddMoreDetailsExplainsItsOptionCount() throws {
        let source = try Self.sourceFile(
            "SharedCore/Screens/TaskDetail/TaskDetailExtrasSectionView.swift"
        )

        #expect(source.contains("countText: actions.count == 1 ? \"1 option\" : \"\\(actions.count) options\""))
    }

    @Test
    func iosTaskDetailsHideEmptyLinkedTasksBehindAddMoreDetails() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let todoContent = try Self.sourceSection(
            startingAt: "private var todoDetailContent",
            endingAt: "private var taskDetailContent",
            in: source
        )
        let routineContent = try Self.sourceSection(
            startingAt: "private var taskDetailContent",
            endingAt: "private var focusSessionSection",
            in: source
        )
        let optionalActions = try Self.sourceSection(
            startingAt: "private var optionalDetailActions",
            endingAt: "private var shouldShowCommentsSection",
            in: source
        )
        let relationshipVisibility = try Self.sourceSection(
            startingAt: "private var shouldShowRelationshipsSection",
            endingAt: "private var shouldShowLinkedEventsSection",
            in: source
        )

        #expect(todoContent.contains("if shouldShowRelationshipsSection"))
        #expect(routineContent.contains("if shouldShowRelationshipsSection"))
        #expect(relationshipVisibility.contains("!store.resolvedRelationships.isEmpty"))
        #expect(!relationshipVisibility.contains("true"))
        #expect(optionalActions.contains("if !shouldShowRelationshipsSection"))
        #expect(optionalActions.contains("title: \"Linked Task\""))
        #expect(optionalActions.contains("store.send(.openAddLinkedTask)"))
    }

    @Test
    func macTaskDetailsHideEmptyLinkedTasksBehindAddMoreDetails() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let todoContent = try Self.sourceSection(
            startingAt: "private var todoDetailContent",
            endingAt: "private var taskDetailContent",
            in: source
        )
        let routineContent = try Self.sourceSection(
            startingAt: "private var taskDetailContent",
            endingAt: "private var taskDetailActionCluster",
            in: source
        )
        let optionalActions = try Self.sourceSection(
            startingAt: "private var optionalDetailActions",
            endingAt: "private var shouldShowCommentsSection",
            in: source
        )
        let relationshipVisibility = try Self.sourceSection(
            startingAt: "private var shouldShowRelationshipsSection",
            endingAt: "private var shouldShowLinkedEventsSection",
            in: source
        )

        #expect(todoContent.contains("if shouldShowRelationshipsSection"))
        #expect(routineContent.contains("if shouldShowRelationshipsSection"))
        #expect(relationshipVisibility.contains("!store.resolvedRelationships.isEmpty"))
        #expect(!relationshipVisibility.contains("true"))
        #expect(optionalActions.contains("if !shouldShowRelationshipsSection"))
        #expect(optionalActions.contains("title: \"Linked Task\""))
        #expect(optionalActions.contains("inlineEditSectionAction(title: \"Linked Task\", section: .linkedTasks)"))
    }

    private func assertOptionalActionsAreLast(in content: String) throws {
        let optionalActions = try #require(content.range(of: "optionalActionsSection"))
        let extras = try #require(content.range(of: "taskExtrasSection"))
        #expect(extras.upperBound < optionalActions.lowerBound)
    }

    private static func sourceSection(
        startingAt startMarker: String,
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
