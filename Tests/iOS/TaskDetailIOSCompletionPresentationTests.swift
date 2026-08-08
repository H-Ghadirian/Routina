import Testing
@testable @preconcurrency import Routina

struct TaskDetailIOSCompletionPresentationTests {
    @Test
    func cadenceFreeRoutineShowsAnotherCompletionAfterLoggingToday() {
        let now = Date()
        let task = RoutineTask(
            name: "Cycle",
            lastDone: now,
            trackingCadenceEnabled: false
        )
        let state = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: now
        )

        #expect(TaskDetailIOSCompletionPresentation.title(for: state) == "Log another completion")
        #expect(TaskDetailIOSCompletionPresentation.systemImage(for: state) == "plus.circle.fill")
    }

    @Test
    func freshCadenceFreeRoutineKeepsThePrimaryDoneAction() {
        let now = Date()
        let task = RoutineTask(
            name: "Cycle",
            trackingCadenceEnabled: false
        )
        let state = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: now
        )

        #expect(TaskDetailIOSCompletionPresentation.title(for: state) == "Done")
        #expect(TaskDetailIOSCompletionPresentation.systemImage(for: state) == nil)
    }
}
