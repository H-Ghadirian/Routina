import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct DayPlanSlotActionPresentationTests {
    @Test
    func visibleSlotActionModesHideSleepWhenAwayExperimentIsOff() {
        #expect(DayPlanSlotActionMode.visibleCases(includingAway: false) == [.task])
        #expect(DayPlanSlotActionMode.visibleCases(includingAway: true) == [.task, .away])
    }

    @Test
    func slotActionModePickerOnlyShowsForMultipleModes() {
        #expect(DayPlanSlotActionMode.showsModePicker(includingAway: false) == false)
        #expect(DayPlanSlotActionMode.showsModePicker(includingAway: true) == true)
    }

    @Test
    func taskPickerFiltersTasksAndCreatesOnlyNewNames() {
        let report = RoutineTask(name: "Write report")
        let email = RoutineTask(name: "Email Jose")
        let tasks = [report, email]

        #expect(DayPlanSlotTaskPickerPresentation.filteredTasks(tasks, matching: "report").map { DayPlanTaskSorting.title(for: $0) } == ["Write report"])
        #expect(DayPlanSlotTaskPickerPresentation.filteredTasks(tasks, matching: "JOSE").map { DayPlanTaskSorting.title(for: $0) } == ["Email Jose"])
        #expect(DayPlanSlotTaskPickerPresentation.creatableTaskName(from: "  Draft   plan  ", tasks: tasks) == "Draft plan")
        #expect(DayPlanSlotTaskPickerPresentation.creatableTaskName(from: "write report", tasks: tasks) == nil)
        #expect(DayPlanSlotTaskPickerPresentation.creatableTaskName(from: "   ", tasks: tasks) == nil)
    }
}
