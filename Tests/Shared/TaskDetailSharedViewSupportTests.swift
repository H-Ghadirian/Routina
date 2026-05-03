import Foundation
import ComposableArchitecture
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
    func durationTextFormatsMinutesHoursAndMixedDurations() {
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 1) == "1 minute")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 25) == "25 minutes")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 60) == "1 hour")
        #expect(TaskDetailHeaderBadgePresentation.durationText(for: 125) == "2 hours 5 minutes")
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

        state.editRoutineName = "   "
        #expect(TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: state)) == false)
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
    func checklistPresentationSortsAndSummarizesDueItems() {
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

        #expect(sortedItems.map(\.title) == ["Milk", "Coffee"])
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
    func attachmentPresentationSanitizesImageFileNamesAndDetectsTypes() {
        let task = RoutineTask(name: "Routine Image?!")

        #expect(TaskDetailAttachmentPresentation.sanitizedAttachmentBaseName("Routine Image?!") == "Routine-Image")
        #expect(TaskDetailAttachmentPresentation.detectedImageFileExtension(for: Data([0x89, 0x50, 0x4E, 0x47])) == "png")
        #expect(TaskDetailAttachmentPresentation.detectedImageFileExtension(for: Data([0xFF, 0xD8, 0xFF])) == "jpg")
        #expect(TaskDetailAttachmentPresentation.taskImageFileName(for: task, data: Data([0x47, 0x49, 0x46, 0x38])) == "Routine-Image.gif")
    }
}
