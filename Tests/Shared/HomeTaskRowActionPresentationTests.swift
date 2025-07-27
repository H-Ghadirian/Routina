import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeTaskRowActionPresentationTests {
    @Test
    func activeRoutineIncludesCompletionLifecycleMoveAndPinActions() {
        let taskID = UUID()
        let context = HomeTaskListMoveContext(
            sectionKey: "onTrack",
            orderedTaskIDs: [UUID(), taskID, UUID()]
        )

        let presentation = HomeTaskRowActionPresentation.make(
            for: TestTaskRowDisplay(taskID: taskID, steps: ["Start"]),
            includeMarkDone: true,
            moveContext: context,
            allowsPinning: true,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        #expect(presentation.openCommand == .open(taskID))
        #expect(presentation.deleteCommand == .delete(taskID))
        #expect(presentation.lifecycleActions == [
            .markDone(title: "Complete Next Step", isDisabled: false),
            .notToday,
            .pause
        ])
        #expect(presentation.moveActions.map(\.direction) == [.top, .up, .down, .bottom])
        #expect(presentation.moveActions.map(\.isDisabled) == [false, false, false, false])
        #expect(presentation.moveActions.first?.command(taskID: taskID) == .moveTaskInSection(
            taskID: taskID,
            sectionKey: "onTrack",
            orderedTaskIDs: context.orderedTaskIDs,
            direction: .top
        ))
        #expect(presentation.pinAction == HomeTaskRowPinActionPresentation(taskID: taskID, isPinned: false))
    }

    @Test
    func pausedTaskOnlyOffersResumeLifecycleAction() {
        let taskID = UUID()
        let presentation = HomeTaskRowActionPresentation.make(
            for: TestTaskRowDisplay(taskID: taskID, isPaused: true),
            includeMarkDone: true,
            allowsPinning: false,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        #expect(presentation.lifecycleActions == [.resume])
        #expect(presentation.moveActions.isEmpty)
        #expect(presentation.pinAction == nil)
    }

    @Test
    func completedOneOffSuppressesLifecycleActions() {
        let presentation = HomeTaskRowActionPresentation.make(
            for: TestTaskRowDisplay(isOneOffTask: true, isCompletedOneOff: true),
            includeMarkDone: true,
            allowsPinning: false,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        #expect(presentation.lifecycleActions.isEmpty)
    }

    @Test
    func moveActionsDisableAtSectionBoundaries() {
        let taskID = UUID()
        let context = HomeTaskListMoveContext(
            sectionKey: "pinned",
            orderedTaskIDs: [taskID, UUID()]
        )

        let presentation = HomeTaskRowActionPresentation.make(
            for: TestTaskRowDisplay(taskID: taskID),
            includeMarkDone: false,
            moveContext: context,
            allowsPinning: false,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        #expect(presentation.lifecycleActions == [.notToday, .pause])
        #expect(presentation.moveActions.map(\.isDisabled) == [true, true, false, false])
    }

    @Test
    func completionPresentationHandlesChecklistAndFutureCalendarTasks() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let emptyChecklist = TestTaskRowDisplay(
            scheduleMode: .derivedFromChecklist,
            dueChecklistItemCount: 0
        )
        let futureCalendarTask = TestTaskRowDisplay(
            recurrenceRule: .weekly(on: 2),
            dueDate: referenceDate.addingTimeInterval(60)
        )

        #expect(HomeTaskRowCompletionPresentation.markDoneLabel(for: emptyChecklist) == "No Due Items")
        #expect(HomeTaskRowCompletionPresentation.isMarkDoneDisabled(emptyChecklist, referenceDate: referenceDate))
        #expect(HomeTaskRowCompletionPresentation.isMarkDoneDisabled(futureCalendarTask, referenceDate: referenceDate))
    }
}

private struct TestTaskRowDisplay: HomeTaskRowDisplay, Equatable {
    var taskID: UUID = UUID()
    var name: String = "Task"
    var emoji: String = "✅"
    var notes: String?
    var placeID: UUID?
    var placeName: String?
    var tags: [String] = []
    var steps: [String] = []
    var interval: Int = 7
    var recurrenceRule: RoutineRecurrenceRule = .interval(days: 7)
    var scheduleMode: RoutineScheduleMode = .fixedInterval
    var createdAt: Date?
    var lastDone: Date?
    var dueDate: Date?
    var priority: RoutineTaskPriority = .none
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var pressure: RoutineTaskPressure = .none
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var pinnedAt: Date?
    var daysUntilDue: Int = 7
    var isOneOffTask: Bool = false
    var isCompletedOneOff: Bool = false
    var isCanceledOneOff: Bool = false
    var isDoneToday: Bool = false
    var isPaused: Bool = false
    var isPinned: Bool = false
    var isInProgress: Bool = false
    var completedChecklistItemCount: Int = 0
    var dueChecklistItemCount: Int = 0
    var manualSectionOrders: [String: Int] = [:]
    var todoState: TodoState?
}
