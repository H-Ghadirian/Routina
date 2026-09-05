import Foundation
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
struct TaskDetailTransitionPresentationTests {
    @Test
    func confirmedAssumedCompletionReservesItsPreviousStatusCardHeight() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let task = RoutineTask(
            name: "Eat fruits",
            scheduleMode: .softInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 0, minute: 0)),
            createdAt: calendar.date(byAdding: .day, value: -2, to: today),
            autoAssumeDailyDone: true
        )
        var state = TaskDetailFeature.State(task: task, selectedDate: today)
        let assumedStatusTitle = state.summaryStatusTitle

        #expect(state.completionStatusPillPhase == .assumed)
        #expect(state.assumedCompletionStatusHeightReservationText == nil)

        state.task.lastDone = today
        state.logs = [RoutineLog(timestamp: today, taskID: task.id, kind: .completed)]
        state.isDoneToday = true
        state.isAssumedDoneToday = false
        state.assumedCompletionAcknowledgement = .init(
            day: today,
            previousStatusTitle: assumedStatusTitle
        )

        let rows = TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: nil,
            layout: .mobile
        )

        #expect(state.completionStatusPillPhase == .confirmed)
        #expect(rows.first?.first?.heightReservationValue == assumedStatusTitle)

        state.assumedCompletionAcknowledgement = nil
        let reopenedRows = TaskDetailHeaderBadgePresentation.routineBadgeRows(
            state: state,
            summaryStatusColor: .green,
            dueDateMetadataDisplayText: nil,
            layout: .mobile
        )

        #expect(state.completionStatusPillPhase == nil)
        #expect(reopenedRows.first?.first?.heightReservationValue == nil)
    }
}
