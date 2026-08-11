import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct BacklogTaskListPresentationTests {
    @Test
    func placesExplicitBacklogTasksInTheirSectionHierarchyAndFlaggedTasksInTheInbox() {
        let writingID = UUID()
        let researchID = UUID()
        let flaggedTask = RoutineTask(name: "Follow up", flags: ["Off radar"])
        let directTask = RoutineTask(name: "Draft article", customTaskSectionID: writingID)
        let nestedTask = RoutineTask(name: "Read sources", customTaskSectionID: researchID)
        let radarTask = RoutineTask(name: "Today task")
        let sections = [
            HomeCustomTaskSection(
                id: writingID,
                surface: .backlog,
                title: "Writing",
                createdAt: nil
            ),
            HomeCustomTaskSection(
                id: researchID,
                parentSectionID: writingID,
                surface: .backlog,
                title: "Research",
                createdAt: nil
            )
        ]
        let flagRules = [RoutineFlagRule(flag: "Off radar", kind: .hideFromTaskLists)]

        let presentation = BacklogTaskListPresentation.make(
            tasks: [flaggedTask, directTask, nestedTask, radarTask],
            customSections: sections,
            flagRules: flagRules,
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.sections.count == 1)
        #expect(presentation.sections.first?.section.id == writingID)
        #expect(presentation.sections.first?.tasks.map(\.id) == [directTask.id])
        #expect(presentation.sections.first?.subsections.map(\.section.id) == [researchID])
        #expect(presentation.sections.first?.subsections.first?.tasks.map(\.id) == [nestedTask.id])
        #expect(presentation.hiddenByFlagTasks.map(\.id) == [flaggedTask.id])
        #expect(presentation.taskCount == 3)
    }

    @Test
    func doesNotTurnCompletedFlaggedTodosIntoAnUnboundedBacklogHistory() {
        let completed = RoutineTask(
            name: "Already done",
            flags: ["Off radar"],
            scheduleMode: .oneOff,
            lastDone: Date(timeIntervalSince1970: 100)
        )

        let presentation = BacklogTaskListPresentation.make(
            tasks: [completed],
            customSections: [],
            flagRules: [RoutineFlagRule(flag: "Off radar", kind: .hideFromTaskLists)],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.isEmpty)
    }
}
