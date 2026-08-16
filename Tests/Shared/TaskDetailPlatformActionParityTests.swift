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
        #expect(toolbarSource.contains(".accessibilityLabel(\"More task actions\")"))
        #expect(!toolbarSource.contains("RoutinaDeepLinkShareMenu("))
        #expect(!actionControlsSource.contains("TaskDetailCancelTodoButton"))
        #expect(!editSource.contains("onDelete:"))
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
