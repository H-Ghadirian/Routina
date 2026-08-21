import Foundation
import ComposableArchitecture
import SwiftUI
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct TaskDetailSharedViewSupportTests {
    @Test
    func linkedTaskActionsNameCreationAndExistingTaskLinkingDistinctly() {
        #expect(TaskRelationshipActionPresentation.createTaskTitle == "Create and Link New Task")
        #expect(TaskRelationshipActionPresentation.linkTaskTitle == "Link Existing Task")
    }

    @Test
    func relationshipKindsReadAsSentenceFragmentsFromTheCurrentTask() {
        #expect(RoutineTaskRelationshipKind.related.sentenceFragment == "is related to")
        #expect(RoutineTaskRelationshipKind.blockedBy.sentenceFragment == "is blocked by")
        #expect(RoutineTaskRelationshipKind.blocks.sentenceFragment == "blocks")
        #expect(RoutineTaskRelationshipKind.doneWhen.sentenceFragment == "is done when")
        #expect(RoutineTaskRelationshipKind.completes.sentenceFragment == "completes")
        #expect(RoutineTaskRelationshipKind.canBeCompletedBy.sentenceFragment == "can be completed by")
        #expect(RoutineTaskRelationshipKind.canComplete.sentenceFragment == "can complete")
    }

    @Test
    func behaviorBearingRelationshipsExplainTheirDirectionBeforeSaving() {
        #expect(
            TaskRelationshipActionPresentation.effectDescription(
                kind: .blockedBy,
                sourceTaskTitle: "Walk in the Zoo",
                targetTaskTitle: "Buy tickets"
            ) == "\u{201c}Walk in the Zoo\u{201d} stays blocked until \u{201c}Buy tickets\u{201d} is completed."
        )
        #expect(
            TaskRelationshipActionPresentation.effectDescription(
                kind: .completes,
                sourceTaskTitle: "Go to the gym",
                targetTaskTitle: "Exercise"
            ) == "Completing \u{201c}Go to the gym\u{201d} automatically completes \u{201c}Exercise\u{201d}."
        )
        #expect(
            TaskRelationshipActionPresentation.effectDescription(
                kind: .related,
                sourceTaskTitle: "Walk in the Zoo",
                targetTaskTitle: "Reward myself"
            ) == "\u{201c}Walk in the Zoo\u{201d} and \u{201c}Reward myself\u{201d} are related. Neither task affects the other."
        )
    }

    @Test
    func linkTaskComposerGroupsKindsAndConfirmsManualSelection() throws {
        let source = try Self.sourceFile("SharedCore/Views/TaskRelationshipsEditor.swift")

        #expect(source.contains("relationshipSection(\"General\", kinds: [.related])"))
        #expect(source.contains("relationshipSection(\"Dependency\", kinds: [.blockedBy, .blocks])"))
        #expect(source.contains("relationshipSection(\"Automatic Completion\", kinds: [.doneWhen, .completes])"))
        #expect(source.contains("relationshipSection(\"Optional Completion\", kinds: [.canBeCompletedBy, .canComplete])"))
        #expect(source.contains("if !isShowingSuggestions {\n                        relationshipTypeSelector"))
        #expect(source.contains("selectedCandidateID = candidate.id"))
        #expect(source.contains("Button(\"Add Relationship\")"))
    }

    @Test
    func linkedTasksCardUsesCountAndOneMacAddEntryPoint() throws {
        let source = try Self.sourceFile(
            "SharedCore/Screens/TaskDetail/TaskDetailRelationshipsSectionView.swift"
        )

        #expect(source.contains("Text(relationshipCount.formatted())"))
        #expect(source.contains("if let onLinkExistingTask"))
        #expect(source.contains("Label(\"Add\", systemImage: \"plus\")"))
        #expect(!source.contains("@Binding var selectedRelationshipKind"))
        #expect(!source.contains("TaskRelationshipActionPresentation.linkTaskTitle"))
    }

    @Test
    func macTaskDetailLinkActionOpensPickerWithoutRevealingDuplicateEditor() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let actionStart = try #require(source.range(of: "private func openExistingTaskLinker()"))
        let actionEnd = try #require(
            source.range(
                of: "private var existingTaskLinkerSheet",
                range: actionStart.upperBound..<source.endIndex
            )
        )
        let actionSource = String(source[actionStart.lowerBound..<actionEnd.lowerBound])

        #expect(actionSource.contains("isExistingTaskLinkerPresented = true"))
        #expect(!actionSource.contains("revealInlineEditSection"))
        #expect(source.contains(".sheet(isPresented: $isExistingTaskLinkerPresented)"))
        #expect(source.contains("store.send(.detailLinkExistingTask(taskID, kind))"))
    }

    @Test
    func macTaskDetailTimeEditorCanReplaceAnExistingTaskTotal() throws {
        let detailSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let headerSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTimeSpentHeaderBox.swift"
        )
        let editActionStart = try #require(detailSource.range(of: "private func beginEditingTaskTime()"))
        let editActionEnd = try #require(
            detailSource.range(
                of: "private func addCompletedFocusToTimeSpent",
                range: editActionStart.upperBound..<detailSource.endIndex
            )
        )
        let editActionSource = String(detailSource[editActionStart.lowerBound..<editActionEnd.lowerBound])

        #expect(detailSource.contains(".sheet(isPresented: $timeEditing.isEditingTaskTimeSpent)"))
        #expect(detailSource.contains("store.send(.updateTaskDuration(timeEditing.editingMinutes))"))
        #expect(editActionSource.contains("timeEditing.beginEditingTask(store.task)"))
        #expect(headerSource.contains("let onEditTotal: () -> Void"))
        #expect(headerSource.contains("Label(\"Edit total\", systemImage: \"pencil\")"))
    }

    @Test
    func macTaskDetailsKeepTaskLadderGroupActivationInTheEditor() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let editorSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormMacCards.swift"
        )

        #expect(!source.contains("taskLadderGroupSection"))
        #expect(!source.contains("Use as Task Ladder group"))
        #expect(editorSource.contains("Toggle(\"Use as Task Ladder group\""))
    }

    @Test
    func taskDetailStateControlsUseRelationshipAwareTodoState() throws {
        let macDetail = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let macControls = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let iosDetail = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let iosControls = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailActionControls.swift"
        )

        for detail in [macDetail, iosDetail] {
            #expect(detail.contains("|| store.hasActiveRelationshipBlocker"))
        }
        for controls in [macControls, iosControls] {
            #expect(controls.contains("store.effectiveTodoState ?? .ready"))
            #expect(controls.contains("store.selectableTodoStates"))
        }
        #expect(macControls.contains("return \"by linked task\""))
        #expect(iosControls.contains("!store.isTodoStateDerivedFromRelationshipBlocker"))
    }

    @Test
    func durationTextFormatsMinutesHoursAndMixedDurations() {
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 1) == "1 minute")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 25) == "25 minutes")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 60) == "1 hour")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 125) == "2 hours 5 minutes")
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
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

    @Test
    func displayedActualDurationUsesTodoStoredValueAndRoutineLogs() {
        let todo = RoutineTask(
            name: "Buy milk",
            scheduleMode: .oneOff,
            actualDurationMinutes: 15
        )
        let routine = RoutineTask(name: "Practice", scheduleMode: .fixedInterval)
        let logs = [
            RoutineLog(taskID: routine.id, kind: .completed, actualDurationMinutes: 20),
            RoutineLog(taskID: routine.id, kind: .canceled, actualDurationMinutes: 30),
            RoutineLog(taskID: routine.id, kind: .completed, actualDurationMinutes: 25)
        ]

        #expect(TaskDetailHeaderBadgePresentation.displayedActualDurationMinutes(task: todo, logs: logs) == 15)
        #expect(TaskDetailHeaderBadgePresentation.displayedActualDurationMinutes(task: routine, logs: logs) == 45)
    }

    @Test
    func headerBadgeRowsKeepDesktopTodoPlanningMetricsOutOfBadges() {
        let placeID = UUID()
        let task = RoutineTask(
            name: "Ship report",
            deadline: makeDate("2026-04-26T09:00:00Z"),
            placeID: placeID,
            scheduleMode: .oneOff,
            estimatedDurationMinutes: 30,
            actualDurationMinutes: 45,
            storyPoints: 3
        )
        var state = TaskDetailFeature.State(task: task)
        state.availablePlaces = [
            RoutinePlaceSummary(id: placeID, name: "Office", radiusMeters: 150, linkedRoutineCount: 1)
        ]

        let mobileRows = TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: "Tomorrow",
            layout: .mobile
        )
        let desktopRows = TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: "Tomorrow",
            layout: .desktop
        )

        #expect(mobileRows.map { $0.map(\.title) } == [
            ["Status"],
            ["Location"],
            ["Due"],
            ["Estimate", "Spent", "Points"]
        ])
        #expect(desktopRows.map { $0.map(\.title) } == [
            ["Location"],
            ["Due"]
        ])
    }

    @Test
    func mobileTodoHeaderShowsViewingDateOnlyAwayFromToday() throws {
        let task = RoutineTask(name: "Ship report", scheduleMode: .oneOff)
        var state = TaskDetailFeature.State(task: task)

        let todayRows = TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: nil,
            layout: .mobile
        )
        #expect(todayRows.first?.map(\.title) == ["Status"])

        state.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let pastRows = TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: nil,
            layout: .mobile
        )

        #expect(pastRows.first?.map(\.title) == ["Status", "Viewing"])
        #expect(pastRows.first?.last?.value != "Today")
    }

    @Test
    func oneOffScheduledTimeBlockAppearsInTaskDetailHeader() {
        let task = RoutineTask(
            name: "Watch film",
            availabilityStartDate: makeDate("2026-08-08T00:00:00Z"),
            scheduleMode: .oneOff,
            recurrenceRule: .interval(
                days: 1,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 12, minute: 0),
                    end: RoutineTimeOfDay(hour: 15, minute: 0)
                )
            ),
            recurrenceTimeRangeRole: .scheduledBlock
        )
        let state = TaskDetailFeature.State(task: task)

        let rows = TaskDetailHeaderBadgePresentation.todoBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: nil,
            layout: .desktop
        )

        #expect(rows.map { $0.map(\.title) } == [["Schedule"]])
        #expect(TaskDetailStatusMetadataPresentation.hasVisibleMetadata(for: state))
    }

    @Test
    func headerBadgeRowsPreserveMobileAndDesktopRoutineLayout() {
        let placeID = UUID()
        let task = RoutineTask(
            name: "Practice piano",
            placeID: placeID,
            interval: 2,
            estimatedDurationMinutes: 20,
            storyPoints: 5
        )
        var state = TaskDetailFeature.State(task: task)
        state.availablePlaces = [
            RoutinePlaceSummary(id: placeID, name: "Studio", radiusMeters: 150, linkedRoutineCount: 1)
        ]
        state.logs = [
            RoutineLog(taskID: task.id, kind: .completed, actualDurationMinutes: 25),
            RoutineLog(taskID: task.id, kind: .canceled)
        ]

        let mobileRows = TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: "Apr 26",
            layout: .mobile
        )
        let desktopRows = TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: "Apr 26",
            layout: .desktop
        )

        #expect(mobileRows.map { $0.map(\.title) } == [
            ["Status", "Frequency"],
            ["Due"],
            ["Location", "Completed"],
            ["Canceled"],
            ["Estimate", "Spent", "Points"]
        ])
        #expect(desktopRows.map { $0.map(\.title) } == [
            ["Status", "Frequency"],
            ["Completed", "Canceled", "Due"],
            ["Location"],
            ["Estimate"]
        ])
    }

    @Test
    func gentleRoutineFrequencyUsesConfiguredCadence() {
        let task = RoutineTask(
            name: "Stretch",
            scheduleMode: .softInterval,
            interval: 1
        )
        let state = TaskDetailFeature.State(task: task)

        #expect(state.frequencyText == "Every day")
    }

    @Test
    func cadenceFreeRoutineFrequencyDoesNotExposeFallbackDailyRule() {
        let task = RoutineTask(
            name: "Go to library",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            trackingCadenceEnabled: false
        )
        let state = TaskDetailFeature.State(task: task)

        #expect(state.frequencyText == "None")
    }

    @Test
    func statusMetadataItemsBuildSharedTaskDetailRows() {
        let referenceDate = makeDate("2026-04-25T10:00:00Z")
        let task = RoutineTask(
            name: "Write report",
            imageData: Data([1]),
            steps: [
                RoutineStep(title: "Outline"),
                RoutineStep(title: "Draft")
            ],
            scheduleMode: .fixedInterval,
            interval: 2
        )
        var state = TaskDetailFeature.State(task: task)
        state.logs = [
            RoutineLog(taskID: task.id, kind: .completed, actualDurationMinutes: 35)
        ]
        state.taskAttachments = [
            AttachmentItem(fileName: "notes.txt", data: Data([2]))
        ]

        let items = TaskDetailStatusMetadataPresentation.items(
            for: state,
            showSelectedDate: true,
            displayedActualDurationText: "35 minutes",
            dueDateMetadataDisplayText: "Tomorrow",
            referenceDate: referenceDate
        )

        #expect(items.map(\.id).contains("frequency"))
        #expect(items.map(\.id).contains("completed"))
        #expect(items.map(\.id).contains("timeSpent"))
        #expect(items.first { $0.id == "attachments" }?.value == "1 image, 1 file")
        #expect(items.first { $0.id == "stepProgress" }?.value == "2 sequential steps")
        #expect(items.first { $0.id == "nextStep" }?.value == "Outline")
    }

    @Test
    func statusMetadataShowsSavedOneOffReminder() {
        let reminderAt = makeDate("2026-08-25T13:00:00Z")
        let task = RoutineTask(
            name: "Physiotherapist",
            reminderAt: reminderAt,
            scheduleMode: .oneOff
        )
        let state = TaskDetailFeature.State(task: task)

        let items = TaskDetailStatusMetadataPresentation.items(
            for: state,
            showSelectedDate: false,
            displayedActualDurationText: nil,
            dueDateMetadataDisplayText: nil
        )

        #expect(TaskDetailStatusMetadataPresentation.hasVisibleMetadata(for: state))
        #expect(items.first { $0.id == "reminder" }?.label == "Reminder")
        #expect(items.first { $0.id == "reminder" }?.value == state.reminderMetadataText)
        #expect(items.first { $0.id == "reminder" }?.systemImage == "bell.fill")
    }

    @Test
    func statusMetadataSummarizesVoiceNotesAsAttachments() {
        let task = RoutineTask(
            name: "Call supplier",
            voiceNoteData: Data([1, 2, 3]),
            voiceNoteDurationSeconds: 3
        )
        let state = TaskDetailFeature.State(task: task)

        let items = TaskDetailStatusMetadataPresentation.items(
            for: state,
            showSelectedDate: false,
            displayedActualDurationText: nil,
            dueDateMetadataDisplayText: nil
        )

        #expect(items.first { $0.id == "attachments" }?.value == "1 voice note")
    }

    @Test
    func optionalTimeSpentVisibilityCanIncludeFocusTimer() {
        let task = RoutineTask(name: "Focus later", scheduleMode: .oneOff, focusModeEnabled: true)

        #expect(!TaskDetailOptionalControlVisibility.showsTimeSpent(for: task))
        #expect(TaskDetailOptionalControlVisibility.showsTimeSpent(for: task, showsFocusTimer: true))
    }

    @Test
    func priorityVisibilityRequiresSavedNonDefaultValues() {
        let neutralTask = RoutineTask(name: "Neutral")
        let legacyMediumTask = RoutineTask(name: "Legacy medium", priority: .medium)
        let explicitlyRevealedMediumTask = RoutineTask(
            name: "Explicit medium",
            priority: .medium,
            showsTaskDetailPriority: true
        )
        let prioritizedTask = RoutineTask(name: "Prioritized", priority: .high)
        let importantTask = RoutineTask(name: "Important", importance: .level3)
        let urgentTask = RoutineTask(name: "Urgent", urgency: .level3)

        #expect(!TaskDetailOptionalControlVisibility.showsPriority(for: neutralTask))
        #expect(!TaskDetailOptionalControlVisibility.showsPriority(for: legacyMediumTask))
        #expect(TaskDetailOptionalControlVisibility.showsPriority(for: explicitlyRevealedMediumTask))
        #expect(TaskDetailOptionalControlVisibility.showsPriority(for: prioritizedTask))
        #expect(TaskDetailOptionalControlVisibility.showsPriority(for: importantTask))
        #expect(TaskDetailOptionalControlVisibility.showsPriority(for: urgentTask))
    }

    @Test
    func taskDetailsPresentImportanceAndUrgencyAsIndependentControls() throws {
        let iosDetail = try Self.sourceFile("iOS/Screens/TaskDetail/TaskDetailTCAView.swift")
        let iosControls = try Self.sourceFile("iOS/Screens/TaskDetail/TaskDetailActionControls.swift")
        let macDetail = try Self.sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift")
        let macControls = try Self.sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailActionControls.swift")
        let priorityDisclosure = try Self.sourceFile("SharedCore/Screens/TaskDetail/TaskDetailPriorityDisclosureBox.swift")

        #expect(iosDetail.contains("TaskDetailPriorityContextControls("))
        #expect(iosDetail.contains(".revealImportanceInTaskDetail"))
        #expect(iosDetail.contains(".revealUrgencyInTaskDetail"))
        #expect(!iosDetail.contains("TaskDetailPriorityDisclosureBox"))
        #expect(iosControls.contains("struct TaskDetailImportancePickerPill"))
        #expect(iosControls.contains("struct TaskDetailUrgencyPickerPill"))
        #expect(iosControls.contains("TaskDetailImportancePickerPill(store: store)"))
        #expect(iosControls.contains("TaskDetailUrgencyPickerPill(store: store)"))

        #expect(macDetail.contains("TaskDetailPriorityDisclosureBox("))
        #expect(macDetail.contains("TaskDetailPriorityControlsGrid(store: store)"))
        #expect(!macDetail.contains(".revealImportanceInTaskDetail"))
        #expect(!macDetail.contains(".revealUrgencyInTaskDetail"))
        #expect(macControls.contains("struct TaskDetailImportanceSegmentedPicker"))
        #expect(macControls.contains("struct TaskDetailUrgencySegmentedPicker"))
        #expect(macControls.contains("struct TaskDetailPriorityControlsGrid"))
        #expect(!priorityDisclosure.contains("ImportanceUrgencyMatrixPicker"))
    }

    @Test
    func iosTaskDetailsGroupThinkingBelowTheOtherPriorityMetadata() throws {
        let detail = try Self.sourceFile("iOS/Screens/TaskDetail/TaskDetailTCAView.swift")
        let actionControls = try Self.sourceFile("iOS/Screens/TaskDetail/TaskDetailActionControls.swift")
        let todoHeader = try Self.sourceSection(
            startingAt: "private var todoHeaderSection",
            endingAt: "private var todoStateTimingSummary",
            in: detail
        )
        let routineHeader = try Self.sourceSection(
            startingAt: "private var routineHeaderSection",
            endingAt: "private var headerGoalsBox",
            in: detail
        )
        let todoPrimaryAction = try Self.sourceSection(
            startingAt: "struct TaskDetailTodoPrimaryActionSection",
            endingAt: "struct TaskDetailRoutinePrimaryActionSection",
            in: actionControls
        )
        let routinePrimaryAction = try Self.sourceSection(
            startingAt: "struct TaskDetailRoutinePrimaryActionSection",
            endingAt: "struct TaskDetailPrimaryActionButton",
            in: actionControls
        )
        let priorityContextControls = try Self.sourceSection(
            startingAt: "struct TaskDetailPriorityContextControls",
            endingAt: "struct TaskDetailPressurePickerPill",
            in: actionControls
        )

        for header in [todoHeader, routineHeader] {
            #expect(header.contains("TaskDetailPriorityContextControls("))
            #expect(!header.contains("TaskDetailThinkingNeededPickerPill"))
        }

        let importance = try #require(priorityContextControls.range(of: "TaskDetailImportancePickerPill(store: store)"))
        let urgency = try #require(priorityContextControls.range(of: "TaskDetailUrgencyPickerPill(store: store)"))
        let pressure = try #require(priorityContextControls.range(of: "TaskDetailPressurePickerPill(store: store)"))
        let thinking = try #require(priorityContextControls.range(of: "TaskDetailThinkingNeededPickerPill(store: store)"))
        #expect(importance.lowerBound < urgency.lowerBound)
        #expect(urgency.lowerBound < pressure.lowerBound)
        #expect(pressure.lowerBound < thinking.lowerBound)
        #expect(priorityContextControls.contains("dynamicTypeSize.isAccessibilitySize"))
        #expect(priorityContextControls.contains("HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8)"))
        #expect(!todoPrimaryAction.contains("TaskDetailThinkingNeededPickerPill"))
        #expect(!routinePrimaryAction.contains("TaskDetailThinkingNeededPickerPill"))
        #expect(actionControls.contains(".frame(minHeight: 44)"))
        #expect(actionControls.contains(".stroke(tint.opacity(0.30), lineWidth: 1)"))
        #expect(actionControls.contains(".accessibilityLabel(\"Importance\")"))
        #expect(actionControls.contains(".accessibilityLabel(\"Urgency\")"))
        #expect(actionControls.contains(".accessibilityLabel(\"Pressure\")"))
        #expect(actionControls.contains(".accessibilityLabel(\"Thinking needed\")"))
    }

    @Test
    func iosTaskDetailCalendarUsesTaskOwnedDisclosureState() throws {
        let iosDetail = try Self.sourceFile("iOS/Screens/TaskDetail/TaskDetailTCAView.swift")
        let macDetail = try Self.sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift")

        #expect(iosDetail.contains("TaskDetailCalendarDisclosureCard("))
        #expect(iosDetail.contains("isExpanded: store.task.isTaskDetailCalendarExpanded"))
        #expect(iosDetail.contains("store.send(.taskDetailCalendarExpansionChanged($0))"))
        #expect(iosDetail.contains(".contentShape(Rectangle())"))
        #expect(iosDetail.contains(".accessibilityValue(isExpanded ? \"Expanded\" : \"Collapsed\")"))
        #expect(!macDetail.contains("TaskDetailCalendarDisclosureCard("))
    }

    @Test
    func addEventsActionRequiresEventActionsEnabledAndNoLinkedEvents() {
        #expect(TaskDetailEventActionVisibility.shouldShowAddEventsAction(
            hasLinkedEvents: false,
            areEventActionsEnabled: true
        ))
        #expect(!TaskDetailEventActionVisibility.shouldShowAddEventsAction(
            hasLinkedEvents: false,
            areEventActionsEnabled: false
        ))
        #expect(!TaskDetailEventActionVisibility.shouldShowAddEventsAction(
            hasLinkedEvents: true,
            areEventActionsEnabled: true
        ))
    }

    @Test
    func focusSectionShowsForEnabledTaskOrActiveTaskFocus() {
        let task = RoutineTask(name: "Book flights", scheduleMode: .oneOff)
        let otherTask = RoutineTask(name: "Pay rent", scheduleMode: .oneOff)

        #expect(!TaskDetailFocusSessionSectionVisibility.shouldShow(for: task, sessions: []))

        task.focusModeEnabled = true
        #expect(TaskDetailFocusSessionSectionVisibility.shouldShow(for: task, sessions: []))

        task.focusModeEnabled = false
        let activeFocus = FocusSession(taskID: task.id, startedAt: makeDate("2026-06-15T08:00:00Z"))
        #expect(TaskDetailFocusSessionSectionVisibility.shouldShow(for: task, sessions: [activeFocus]))

        let otherActiveFocus = FocusSession(taskID: otherTask.id, startedAt: makeDate("2026-06-15T08:00:00Z"))
        #expect(!TaskDetailFocusSessionSectionVisibility.shouldShow(for: task, sessions: [otherActiveFocus]))

        activeFocus.completedAt = makeDate("2026-06-15T08:25:00Z")
        #expect(!TaskDetailFocusSessionSectionVisibility.shouldShow(for: task, sessions: [activeFocus]))
    }

    @Test
    func completedTodoDoesNotShowRedundantUndoInstruction() {
        let completedTodo = RoutineTask(
            name: "Submit report",
            scheduleMode: .oneOff,
            lastDone: makeDate("2026-04-25T09:00:00Z")
        )
        let state = TaskDetailFeature.State(task: completedTodo)

        #expect(TaskDetailStatusMetadataPresentation.statusContextMessage(
            for: state,
            showPersianDates: false,
            style: .mobile,
            referenceDate: makeDate("2026-04-25T10:00:00Z")
        ) == nil)
        #expect(TaskDetailStatusMetadataPresentation.statusContextMessage(
            for: state,
            showPersianDates: false,
            style: .desktop,
            referenceDate: makeDate("2026-04-25T10:00:00Z")
        ) == nil)
    }

    @Test
    func statusContextAndDueDateCopyUseSharedPresentationRules() {
        var state = TaskDetailFeature.State(task: RoutineTask(name: "Practice"))
        state.selectedDate = makeDate("2026-04-22T08:00:00Z")

        let message = TaskDetailStatusMetadataPresentation.statusContextMessage(
            for: state,
            showPersianDates: false,
            style: .mobile,
            referenceDate: makeDate("2026-04-25T10:00:00Z")
        )

        #expect(message?.hasPrefix("Reviewing ") == true)
        #expect(message?.hasSuffix(".") == true)
        #expect(TaskDetailStatusMetadataPresentation.dueDateMetadataDisplayText(
            rawText: "Apr 26",
            dueDate: nil,
            showPersianDates: true
        ) == "Apr 26")
        #expect(TaskDetailStatusMetadataPresentation.dueDateMetadataDisplayText(
            rawText: "Apr 26",
            dueDate: makeDate("2026-04-26T09:00:00Z"),
            showPersianDates: false
        ) == "Apr 26")
    }

    @Test
    func summaryStatusTitlePrefersMissedExactTimedOccurrenceForChecklistCompletionRoutine() throws {
        let calendar = Calendar.current
        let threeDaysAgo = try #require(calendar.date(byAdding: .day, value: -3, to: Date()))
        let anchorDay = calendar.startOfDay(for: threeDaysAgo)
        let anchor = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: anchorDay))
        let task = RoutineTask(
            name: "Check work emails",
            checklistItems: [RoutineChecklistItem(title: "Inbox", intervalDays: 1)],
            scheduleMode: .fixedIntervalChecklist,
            recurrenceRule: .interval(days: 2, at: RoutineTimeOfDay(hour: 9, minute: 0)),
            scheduleAnchor: anchor,
            createdAt: Date()
        )
        let state = TaskDetailFeature.State(task: task)

        #expect(state.summaryStatusTitle == "Missed")
    }

    @Test
    func visibleStatusMetadataRecognizesRoutineAndPlainTodo() {
        let todoState = TaskDetailFeature.State(task: RoutineTask(name: "Buy milk", scheduleMode: .oneOff))
        let routineState = TaskDetailFeature.State(task: RoutineTask(name: "Practice"))

        #expect(!TaskDetailStatusMetadataPresentation.hasVisibleMetadata(for: todoState))
        #expect(TaskDetailStatusMetadataPresentation.hasVisibleMetadata(for: routineState))
    }

    @Test
    func taskGoalSummariesResolveLinkedGoalsInTaskOrder() {
        let healthID = UUID()
        let focusID = UUID()
        let task = RoutineTask(
            name: "Deep work",
            goalIDs: [focusID, healthID]
        )
        var state = TaskDetailFeature.State(task: task)
        state.availableGoals = [
            RoutineGoalSummary(id: healthID, title: "Health", emoji: "H", color: .green),
            RoutineGoalSummary(id: focusID, title: "Focus", emoji: "F", color: .blue)
        ]

        #expect(state.taskGoalSummaries.map(\.id) == [focusID, healthID])
        #expect(state.taskGoalSummaries.map(\.displayTitle) == ["Focus", "Health"])
    }

    @Test
    func editChangeDetectorTracksPristineChangedAndInvalidNames() {
        let task = RoutineTask(
            name: "Write report",
            emoji: "📝",
            notes: "Draft the weekly notes",
            link: "https://example.com/report",
            priority: .none,
            importance: .level3,
            urgency: .level2,
            pressure: .low,
            tags: ["Writing"],
            scheduleMode: .fixedInterval,
            interval: 2,
            estimatedDurationMinutes: 45,
            storyPoints: 3,
            focusModeEnabled: true
        )
        var state = TaskDetailFeature.State(task: task)
        withDependencies {
            $0.date.now = makeDate("2026-04-25T10:00:00Z")
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)) == false)

        state.editRoutineNotes = "Draft and proofread the weekly notes"
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))

        state.editRoutineNotes = "Draft the weekly notes"
        state.editCustomTaskSectionID = UUID()
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))

        state.editRoutineName = "   "
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)) == false)
    }

    @Test
    func editChangeDetectorTracksGoalSelectionAndDraftChanges() {
        let goalID = UUID()
        let existingGoal = RoutineGoalSummary(id: goalID, title: "Ship portfolio")
        let task = RoutineTask(
            name: "Write report",
            goalIDs: [goalID]
        )
        var state = TaskDetailFeature.State(task: task)
        state.availableGoals = [existingGoal]
        withDependencies {
            $0.date.now = makeDate("2026-04-25T10:00:00Z")
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)) == false)

        state.editRoutineGoals = []
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))

        state.editRoutineGoals = [existingGoal]
        state.editGoalDraft = "Improve health"
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))

        state.editGoalDraft = ""
        state.editRoutineGoals = [existingGoal, RoutineGoalSummary(title: "Improve health")]
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))
    }

    @Test
    func editChangeDetectorTracksAllDayChanges() {
        let task = RoutineTask(name: "Studio day")
        var state = TaskDetailFeature.State(task: task)
        withDependencies {
            $0.date.now = makeDate("2026-04-25T10:00:00Z")
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)) == false)

        state.editIsAllDay = true

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))
    }

    @Test
    func syncEditFormUsesExactAvailabilityAsPlannedDate() {
        let calendar = makeTestCalendar()
        let availabilityDate = makeDate("2026-07-19T11:30:00Z")
        let task = RoutineTask(
            name: "Visit pharmacy",
            availabilityStartDate: availabilityDate,
            scheduleMode: .oneOff
        )
        task.plannedDate = nil
        var state = TaskDetailFeature.State(task: task)

        withDependencies {
            $0.date.now = makeDate("2026-07-18T10:00:00Z")
            $0.calendar = calendar
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        #expect(state.editPlannedDate == makeDate("2026-07-19T00:00:00Z"))
    }

    @Test
    func editChangeDetectorTracksTimeRangeRoleChanges() {
        let task = RoutineTask(
            name: "Group session",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(
                on: 2,
                timeRange: RoutineTimeRange(
                    start: RoutineTimeOfDay(hour: 17, minute: 0),
                    end: RoutineTimeOfDay(hour: 17, minute: 55)
                )
            ),
            recurrenceTimeRangeRole: .availability
        )
        var state = TaskDetailFeature.State(task: task)
        withDependencies {
            $0.date.now = makeDate("2026-04-25T10:00:00Z")
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)) == false)

        state.editRecurrenceTimeRangeRole = .scheduledBlock

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))
    }

    @Test
    func editChangeDetectorAllowsRemovingExistingChecklist() {
        let task = RoutineTask(
            name: "Restock pantry",
            checklistItems: [
                RoutineChecklistItem(title: "Beans", intervalDays: 14),
                RoutineChecklistItem(title: "Rice", intervalDays: 30)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        var state = TaskDetailFeature.State(task: task)
        withDependencies {
            $0.date.now = makeDate("2026-04-25T10:00:00Z")
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        state.editRoutineChecklistItems = []

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))
    }

    @Test
    func editChangeDetectorAllowsChecklistModeWithoutItemsSoSaveCanValidate() {
        let task = RoutineTask(
            name: "Restock pantry",
            scheduleMode: .fixedInterval
        )
        var state = TaskDetailFeature.State(task: task)
        withDependencies {
            $0.date.now = makeDate("2026-04-25T10:00:00Z")
        } operation: {
            TaskDetailFeature().syncEditFormFromTask(&state)
        }

        state.editScheduleMode = .fixedIntervalChecklist

        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)))
    }

    @Test
    func logPresentationBuildsSharedLogAndChangeText() {
        let timestamp = makeDate("2026-04-25T08:30:00Z")
        let log = RoutineLog(
            timestamp: timestamp,
            taskID: UUID(),
            kind: .completed,
            actualDurationMinutes: 90
        )
        let change = RoutineTaskChangeLogEntry(
            timestamp: timestamp,
            kind: .timeSpentAdded,
            durationMinutes: 25
        )

        #expect(TaskDetailLogPresentation.actionTitle(for: log) == "Undo")
        #expect(TaskDetailLogPresentation.timeSpentText(for: log, style: .compact) == "1h 30m")
        #expect(TaskDetailLogPresentation.timeSpentText(for: log, style: .full) == "1 hour 30 minutes")
        #expect(TaskDetailLogPresentation.taskChangeTitle(for: change, relatedTaskName: "task") == "Added 25m time spent")
        #expect(TaskDetailLogPresentation.taskChangeSystemImage(for: change) == "clock")
        #expect(TaskDetailLogPresentation.displayedLogs([log, log, log, log], showingAll: false).count == 3)

        let changes = (0..<13).map { offset in
            RoutineTaskChangeLogEntry(
                timestamp: timestamp.addingTimeInterval(TimeInterval(-offset)),
                kind: .created
            )
        }
        #expect(TaskDetailLogPresentation.displayedTaskChanges(changes, showingAll: false).count == 12)
        #expect(TaskDetailLogPresentation.displayedTaskChanges(changes, showingAll: true).count == 13)
    }

    @Test
    func calendarPresentationBuildsDoneDatesAndRangeState() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-04-25T10:00:00Z")
        let dueDate = makeDate("2026-04-20T10:00:00Z")
        let doneDate = makeDate("2026-04-22T08:00:00Z")
        let task = RoutineTask(
            name: "Practice",
            scheduleMode: .fixedInterval,
            lastDone: doneDate,
            createdAt: makeDate("2026-04-01T08:00:00Z")
        )
        let logs = [
            RoutineLog(timestamp: doneDate, taskID: task.id, kind: .completed)
        ]
        let doneDates = TaskDetailCalendarPresentation.doneDates(from: logs, task: task, calendar: calendar)
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: doneDate,
            doneDates: doneDates,
            assumedDates: [],
            dueDate: dueDate,
            createdAt: task.createdAt,
            pausedAt: makeDate("2026-04-23T12:00:00Z"),
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(doneDates.contains(calendar.startOfDay(for: doneDate)))
        #expect(presentation.isDoneDate)
        #expect(presentation.isDueToTodayRangeDate)
        #expect(!presentation.isToday)
        #expect(presentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationHighlightsSoftDueDateSeparatelyFromOverdueRange() {
        let calendar = makeTestCalendar()
        let softDueDate = makeDate("2026-04-20T10:00:00Z")
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: softDueDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            softDueDate: softDueDate,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: makeDate("2026-04-25T10:00:00Z"),
            calendar: calendar
        )

        #expect(presentation.isSoftDueDate)
        #expect(!presentation.isDueDate)
        #expect(!presentation.isDueToTodayRangeDate)
        #expect(presentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationHighlightsOngoingRangeFromStartedDayThroughToday() {
        let calendar = makeTestCalendar()
        let ongoingSince = makeDate("2026-06-13T09:00:00Z")
        let referenceDate = makeDate("2026-06-15T10:00:00Z")
        let startedDayPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: makeDate("2026-06-13T12:00:00Z"),
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            createdAt: nil,
            pausedAt: nil,
            ongoingSince: ongoingSince,
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let todayPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: referenceDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            createdAt: nil,
            pausedAt: nil,
            ongoingSince: ongoingSince,
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let beforeStartedPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: makeDate("2026-06-12T12:00:00Z"),
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            createdAt: nil,
            pausedAt: nil,
            ongoingSince: ongoingSince,
            isOrangeUrgencyToday: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(startedDayPresentation.isOngoingDate)
        #expect(startedDayPresentation.isHighlightedDay)
        #expect(todayPresentation.isOngoingDate)
        #expect(todayPresentation.isToday)
        #expect(!beforeStartedPresentation.isOngoingDate)
    }

    @Test
    func calendarPresentationKeepsCompletedMultiDaySpanAfterStop() {
        let calendar = makeTestCalendar()
        let startedAt = makeDate("2026-06-13T09:00:00Z")
        let stoppedAt = makeDate("2026-06-15T18:00:00Z")
        let changes = [
            RoutineTaskChangeLogEntry(
                timestamp: stoppedAt,
                kind: .ongoingStopped,
                previousValue: RoutineTaskMultiDaySpanDateStorage.encode(startedAt),
                newValue: RoutineTaskMultiDaySpanDateStorage.encode(stoppedAt)
            )
        ]
        let spanDates = TaskDetailCalendarPresentation.completedMultiDaySpanDates(
            from: changes,
            calendar: calendar
        )
        let startedDay = makeDate("2026-06-13T12:00:00Z")
        let middleDay = makeDate("2026-06-14T12:00:00Z")
        let stoppedDay = makeDate("2026-06-15T12:00:00Z")
        let beforeStartedDay = makeDate("2026-06-12T12:00:00Z")
        let middlePresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: middleDay,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            completedMultiDaySpanDates: spanDates,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: stoppedAt,
            calendar: calendar
        )

        #expect(spanDates.contains(calendar.startOfDay(for: startedDay)))
        #expect(spanDates.contains(calendar.startOfDay(for: middleDay)))
        #expect(spanDates.contains(calendar.startOfDay(for: stoppedDay)))
        #expect(!spanDates.contains(calendar.startOfDay(for: beforeStartedDay)))
        #expect(middlePresentation.isCompletedMultiDaySpanDate)
        #expect(middlePresentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationMarksExactTimedMissedDateWithoutOverdueRange() {
        let calendar = makeTestCalendar()
        let missedDate = makeDate("2026-05-07T18:30:00Z")
        let today = makeDate("2026-05-08T10:00:00Z")
        let nextDueDate = makeDate("2026-05-14T18:30:00Z")

        let missedPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: missedDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nextDueDate,
            missedDates: [calendar.startOfDay(for: missedDate)],
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: today,
            calendar: calendar
        )
        let todayPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: today,
            doneDates: [],
            assumedDates: [],
            dueDate: nextDueDate,
            missedDates: [calendar.startOfDay(for: missedDate)],
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: today,
            calendar: calendar
        )
        let nextDuePresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: nextDueDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nextDueDate,
            missedDates: [calendar.startOfDay(for: missedDate)],
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: today,
            calendar: calendar
        )

        #expect(missedPresentation.isMissedDate)
        #expect(missedPresentation.isHighlightedDay)
        #expect(!todayPresentation.isMissedDate)
        #expect(!todayPresentation.isDueToTodayRangeDate)
        #expect(todayPresentation.isToday)
        #expect(nextDuePresentation.isDueDate)
        #expect(nextDuePresentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationSuppressesOverdueRangeWhenDueDateIsMissed() {
        let calendar = makeTestCalendar()
        let missedDate = makeDate("2026-06-25T18:30:00Z")
        let nextDay = makeDate("2026-06-26T10:00:00Z")
        let today = makeDate("2026-06-27T10:00:00Z")
        let missedDates: Set<Date> = [calendar.startOfDay(for: missedDate)]

        let missedPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: missedDate,
            doneDates: [],
            assumedDates: [],
            dueDate: missedDate,
            missedDates: missedDates,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: today,
            calendar: calendar
        )
        let nextDayPresentation = TaskDetailCalendarPresentation.dayPresentation(
            day: nextDay,
            doneDates: [],
            assumedDates: [],
            dueDate: missedDate,
            missedDates: missedDates,
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: today,
            calendar: calendar
        )

        #expect(missedPresentation.isMissedDate)
        #expect(!missedPresentation.isDueToTodayRangeDate)
        #expect(!nextDayPresentation.isDueToTodayRangeDate)
        #expect(nextDayPresentation.backgroundColor == .clear)
    }

    @Test
    func calendarPresentationUsesStrongerBorderForSelectedDayThanTodayMarker() {
        let selectedWidth = TaskDetailCalendarPresentation.selectionStrokeLineWidth(
            isSelected: true,
            isToday: false,
            isHighlightedDay: false
        )
        let todayHighlightedWidth = TaskDetailCalendarPresentation.selectionStrokeLineWidth(
            isSelected: false,
            isToday: true,
            isHighlightedDay: true
        )
        let plainTodayWidth = TaskDetailCalendarPresentation.selectionStrokeLineWidth(
            isSelected: false,
            isToday: true,
            isHighlightedDay: false
        )
        let plainWidth = TaskDetailCalendarPresentation.selectionStrokeLineWidth(
            isSelected: false,
            isToday: false,
            isHighlightedDay: false
        )

        #expect(selectedWidth > todayHighlightedWidth)
        #expect(todayHighlightedWidth > plainWidth)
        #expect(plainTodayWidth == plainWidth)
    }

    @Test
    func calendarPresentationMarksCanceledOccurrenceSeparatelyFromMissed() {
        let calendar = makeTestCalendar()
        let canceledDate = makeDate("2026-05-07T18:30:00Z")
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: canceledDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            missedDates: [],
            canceledDates: [calendar.startOfDay(for: canceledDate)],
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: calendar
        )

        #expect(presentation.isCanceledDate)
        #expect(!presentation.isMissedDate)
        #expect(presentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationPrefersCanceledWhenCanceledAndMissedShareDate() {
        let calendar = makeTestCalendar()
        let occurrenceDate = makeDate("2026-05-07T18:30:00Z")
        let occurrenceDay = calendar.startOfDay(for: occurrenceDate)
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: occurrenceDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            missedDates: [occurrenceDay],
            canceledDates: [occurrenceDay],
            createdAt: nil,
            pausedAt: nil,
            isOrangeUrgencyToday: false,
            referenceDate: makeDate("2026-05-08T10:00:00Z"),
            calendar: calendar
        )

        #expect(presentation.isCanceledDate)
        #expect(!presentation.isMissedDate)
        #expect(presentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationPrefersCanceledOverPausedWhenSameDate() {
        let calendar = makeTestCalendar()
        let occurrenceDate = makeDate("2026-06-01T17:00:00Z")
        let occurrenceDay = calendar.startOfDay(for: occurrenceDate)
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: occurrenceDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            missedDates: [],
            canceledDates: [occurrenceDay],
            createdAt: nil,
            pausedAt: makeDate("2026-06-01T18:00:00Z"),
            isOrangeUrgencyToday: false,
            referenceDate: makeDate("2026-06-02T10:00:00Z"),
            calendar: calendar
        )

        #expect(presentation.isCanceledDate)
        #expect(!presentation.isPausedDate)
        #expect(presentation.isHighlightedDay)
    }

    @Test
    func calendarPresentationPrefersMissedOverPausedWhenSameDate() {
        let calendar = makeTestCalendar()
        let occurrenceDate = makeDate("2026-06-01T17:00:00Z")
        let occurrenceDay = calendar.startOfDay(for: occurrenceDate)
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: occurrenceDate,
            doneDates: [],
            assumedDates: [],
            dueDate: nil,
            missedDates: [occurrenceDay],
            canceledDates: [],
            createdAt: nil,
            pausedAt: makeDate("2026-06-01T18:00:00Z"),
            isOrangeUrgencyToday: false,
            referenceDate: makeDate("2026-06-02T10:00:00Z"),
            calendar: calendar
        )

        #expect(presentation.isMissedDate)
        #expect(!presentation.isPausedDate)
        #expect(presentation.isHighlightedDay)
    }

    @Test
    func checklistPresentationPreservesItemOrderAndSummarizesDueItems() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-04-25T10:00:00Z")
        let overdue = RoutineChecklistItem(
            title: "Milk",
            intervalDays: 5,
            createdAt: makeDate("2026-04-19T10:00:00Z")
        )
        let dueToday = RoutineChecklistItem(
            title: "Coffee",
            intervalDays: 5,
            createdAt: makeDate("2026-04-20T10:00:00Z")
        )
        let task = RoutineTask(
            name: "Groceries",
            checklistItems: [dueToday, overdue],
            scheduleMode: .derivedFromChecklist
        )

        let sortedItems = TaskDetailChecklistPresentation.sortedItems(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sortedItems.map(\.title) == ["Coffee", "Milk"])
        #expect(TaskDetailChecklistPresentation.statusText(
            for: overdue,
            task: task,
            isMarkedDone: false,
            referenceDate: referenceDate,
            calendar: calendar
        ) == "Overdue by 1 day")
        #expect(TaskDetailChecklistPresentation.statusText(
            for: dueToday,
            task: task,
            isMarkedDone: false,
            referenceDate: referenceDate,
            calendar: calendar
        ) == "Due today")
    }

    @Test
    func checklistRunoutItemIsMarkedDoneOnlyOnResetDay() {
        let calendar = makeTestCalendar()
        let item = RoutineChecklistItem(
            title: "Coffee",
            intervalDays: 3,
            lastPurchasedAt: makeDate("2026-04-25T10:00:00Z")
        )

        #expect(TaskDetailChecklistPresentation.isRunoutItemMarkedDone(
            item,
            referenceDate: makeDate("2026-04-25T20:00:00Z"),
            calendar: calendar
        ))
        #expect(!TaskDetailChecklistPresentation.isRunoutItemMarkedDone(
            item,
            referenceDate: makeDate("2026-04-26T10:00:00Z"),
            calendar: calendar
        ))
    }

    @Test
    func taskDetailStateMarksRunoutItemDoneForSelectedResetDay() {
        let itemID = UUID()
        let doneAt = makeDate("2026-04-25T10:00:00Z")
        let task = RoutineTask(
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(
                    id: itemID,
                    title: "Coffee",
                    intervalDays: 3,
                    lastPurchasedAt: doneAt
                )
            ],
            scheduleMode: .derivedFromChecklist
        )
        var state = TaskDetailFeature.State(
            task: task,
            selectedDate: makeDate("2026-04-25T08:00:00Z")
        )

        #expect(state.isChecklistItemMarkedDone(state.task.checklistItems[0]))

        state.selectedDate = makeDate("2026-04-26T08:00:00Z")

        #expect(!state.isChecklistItemMarkedDone(state.task.checklistItems[0]))
    }

    @Test
    func checklistPresentationHidesDoneItemsUntilRequested() {
        let doneID = UUID()
        let pendingID = UUID()
        let doneItem = RoutineChecklistItem(id: doneID, title: "Done", intervalDays: 1)
        let pendingItem = RoutineChecklistItem(id: pendingID, title: "Pending", intervalDays: 1)
        let items = [doneItem, pendingItem]
        let isMarkedDone: (RoutineChecklistItem) -> Bool = { $0.id == doneID }

        let defaultItems = TaskDetailChecklistPresentation.visibleItems(
            items,
            showDone: false,
            isMarkedDone: isMarkedDone
        )
        let expandedItems = TaskDetailChecklistPresentation.visibleItems(
            items,
            showDone: true,
            isMarkedDone: isMarkedDone
        )

        #expect(defaultItems.map(\.id) == [pendingID])
        #expect(expandedItems.map(\.id) == [doneID, pendingID])
    }

    @Test
    func checklistPresentationKeepsCompletionChecklistRowsVisible() {
        let completionChecklist = RoutineTask(
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(title: "Sciforma", intervalDays: 30),
                RoutineChecklistItem(title: "Excel", intervalDays: 30)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        let optionalChecklist = RoutineTask(
            name: "Read",
            checklistItems: [
                RoutineChecklistItem(title: "Desk", intervalDays: 1)
            ],
            scheduleMode: .fixedInterval
        )

        #expect(!TaskDetailChecklistPresentation.usesDoneVisibilityFilter(for: completionChecklist))
        #expect(TaskDetailChecklistPresentation.usesDoneVisibilityFilter(for: optionalChecklist))
    }

    @Test
    func checklistPresentationShowsItemIntervalsOnlyForRunoutRoutines() {
        let completionChecklist = RoutineTask(
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(title: "Sciforma", intervalDays: 30)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        let optionalChecklist = RoutineTask(
            name: "Read",
            checklistItems: [
                RoutineChecklistItem(title: "Desk", intervalDays: 1)
            ],
            scheduleMode: .fixedInterval
        )
        let runoutChecklist = RoutineTask(
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(title: "Milk", intervalDays: 3)
            ],
            scheduleMode: .derivedFromChecklist
        )

        #expect(!TaskDetailChecklistPresentation.showsItemIntervalControls(for: completionChecklist))
        #expect(!TaskDetailChecklistPresentation.showsItemIntervalControls(for: optionalChecklist))
        #expect(TaskDetailChecklistPresentation.showsItemIntervalControls(for: runoutChecklist))
    }

    @Test
    func checklistPresentationKeepsCompletedChecklistRoutineRowsReadOnly() {
        let now = Date()
        let itemID = UUID()
        let task = RoutineTask(
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: itemID, title: "Sciforma", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        task.completedChecklistItemIDs = [itemID]
        task.completedChecklistProgressStartedAt = now

        #expect(!TaskDetailChecklistPresentation.canToggleItem(
            task.checklistItems[0],
            task: task,
            selectedDate: now,
            isSelectedDateCompleted: true,
            calendar: .current
        ))
    }

    @Test
    func attachmentPresentationSanitizesImageFileNamesAndDetectsTypes() {
        let task = RoutineTask(name: "Routine Image?!")

        #expect(TaskDetailAttachmentPresentation.sanitizedAttachmentBaseName("Routine Image?!") == "Routine-Image")
        #expect(TaskDetailAttachmentPresentation.detectedImageFileExtension(for: Data([0x89, 0x50, 0x4E, 0x47])) == "png")
        #expect(TaskDetailAttachmentPresentation.detectedImageFileExtension(for: Data([0xFF, 0xD8, 0xFF])) == "jpg")
        #expect(TaskDetailAttachmentPresentation.taskImageFileName(for: task, data: Data([0x47, 0x49, 0x46, 0x38])) == "Routine-Image.gif")
    }
}
