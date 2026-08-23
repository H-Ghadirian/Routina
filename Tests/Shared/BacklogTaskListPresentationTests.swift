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
    func routesMatchingUnassignedFlaggedTasksIntoBacklogSuperSections() throws {
        let writingID = UUID()
        let readingID = UUID()
        let matchingTask = RoutineTask(
            name: "Read sources",
            tags: ["Research"],
            flags: ["Off radar"]
        )
        let unmatchedTask = RoutineTask(
            name: "Call carpenter",
            tags: ["Home"],
            flags: ["Off radar"]
        )
        let explicitlyAssignedTask = RoutineTask(
            name: "Already organized",
            customTaskSectionID: readingID,
            tags: ["Research"],
            flags: ["Off radar"]
        )
        let sections = [
            HomeCustomTaskSection(
                id: writingID,
                surface: .backlog,
                title: "Writing",
                createdAt: nil,
                rules: HomeCustomTaskSectionRules(tagNames: ["Research"])
            ),
            HomeCustomTaskSection(
                id: readingID,
                surface: .backlog,
                title: "Reading",
                createdAt: nil
            )
        ]
        let presentation = BacklogTaskListPresentation.make(
            tasks: [matchingTask, unmatchedTask, explicitlyAssignedTask],
            customSections: sections,
            flagRules: [RoutineFlagRule(flag: "Off radar", kind: .hideFromTaskLists)],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        let writingSection = try #require(presentation.sections.first)
        #expect(writingSection.section.id == writingID)
        #expect(writingSection.tasks.map { $0.id } == [matchingTask.id])
        #expect(presentation.sections.last?.section.id == readingID)
        #expect(presentation.sections.last?.tasks.map { $0.id } == [explicitlyAssignedTask.id])
        #expect(presentation.hiddenByFlagTasks.map { $0.id } == [unmatchedTask.id])
    }

    @Test
    func doesNotRouteOrdinaryRadarTasksIntoBacklogByTagRule() {
        let task = RoutineTask(name: "Read sources", tags: ["Research"])
        let section = HomeCustomTaskSection(
            surface: .backlog,
            title: "Writing",
            createdAt: nil,
            rules: HomeCustomTaskSectionRules(tagNames: ["Research"])
        )

        let presentation = BacklogTaskListPresentation.make(
            tasks: [task],
            customSections: [section],
            flagRules: [],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.taskCount == 0)
        #expect(presentation.outsideBacklogResults.isEmpty)
    }

    @Test
    func keepsEmptyBacklogSuperSectionsAndSubsectionsReachable() throws {
        let somedayID = UUID()
        let researchID = UUID()
        let sections = [
            HomeCustomTaskSection(
                id: somedayID,
                surface: .backlog,
                title: "Someday",
                createdAt: nil
            ),
            HomeCustomTaskSection(
                id: researchID,
                parentSectionID: somedayID,
                surface: .backlog,
                title: "Research",
                createdAt: nil
            )
        ]

        let presentation = BacklogTaskListPresentation.make(
            tasks: [],
            customSections: sections,
            flagRules: [],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        let section = try #require(presentation.sections.first)
        #expect(section.id == somedayID)
        #expect(section.subsections.map(\.id) == [researchID])
        #expect(presentation.taskCount == 0)
        #expect(!presentation.isEmpty)
    }

    @Test
    func searchFiltersEveryBacklogGroupAndRetainsMatchingHierarchy() throws {
        let writingID = UUID()
        let researchID = UUID()
        let writingTask = RoutineTask(name: "Draft article", customTaskSectionID: writingID)
        let nestedTask = RoutineTask(
            name: "Read sources",
            notes: "Interview Ada",
            customTaskSectionID: researchID
        )
        let hiddenTask = RoutineTask(name: "Call carpenter", flags: ["Off radar"])
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

        let noteMatch = BacklogTaskListPresentation.make(
            tasks: [writingTask, nestedTask, hiddenTask],
            customSections: sections,
            flagRules: flagRules,
            searchText: "interview",
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )
        let section = try #require(noteMatch.sections.first)
        #expect(section.tasks.isEmpty)
        #expect(section.subsections.first?.tasks.map(\.id) == [nestedTask.id])
        #expect(noteMatch.hiddenByFlagTasks.isEmpty)

        let pathMatch = BacklogTaskListPresentation.make(
            tasks: [writingTask, nestedTask, hiddenTask],
            customSections: sections,
            flagRules: flagRules,
            searchText: "research",
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )
        #expect(pathMatch.sections.first?.subsections.first?.tasks.map(\.id) == [nestedTask.id])

        let hiddenMatch = BacklogTaskListPresentation.make(
            tasks: [writingTask, nestedTask, hiddenTask],
            customSections: sections,
            flagRules: flagRules,
            searchText: "carpenter",
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )
        #expect(hiddenMatch.sections.isEmpty)
        #expect(hiddenMatch.hiddenByFlagTasks.map(\.id) == [hiddenTask.id])
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

    @Test
    func searchKeepsMatchingRadarTasksOutsideBacklogWithTheirLocation() throws {
        let somedayID = UUID()
        let futureID = UUID()
        let backlogTask = RoutineTask(
            name: "Read a novel",
            customTaskSectionID: somedayID
        )
        let radarTask = RoutineTask(
            name: "Read mail",
            customTaskSectionID: futureID,
            scheduleMode: .oneOff
        )
        let sections = [
            HomeCustomTaskSection(
                id: somedayID,
                surface: .backlog,
                title: "Someday",
                createdAt: nil
            ),
            HomeCustomTaskSection(
                id: futureID,
                surface: .radar,
                title: "Future",
                createdAt: nil
            )
        ]

        let presentation = BacklogTaskListPresentation.make(
            tasks: [backlogTask, radarTask],
            customSections: sections,
            flagRules: [],
            searchText: "read mail",
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(presentation.taskCount == 0)
        let result = try #require(presentation.outsideBacklogResults.first)
        #expect(result.task.id == radarTask.id)
        #expect(result.locationTitle == "Main task list › Future")
        #expect(result.revealDestination == .planner)
    }

    @Test
    func completedSearchMatchesRevealTheirActivityInTimeline() throws {
        let completedTask = RoutineTask(
            name: "Watch the recording",
            scheduleMode: .oneOff,
            lastDone: Date(timeIntervalSince1970: 500)
        )

        let presentation = BacklogTaskListPresentation.make(
            tasks: [completedTask],
            customSections: [],
            flagRules: [],
            searchText: "watch",
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )

        let result = try #require(presentation.outsideBacklogResults.first)
        #expect(result.task.id == completedTask.id)
        #expect(result.locationTitle == "Completed")
        #expect(result.revealDestination == .timeline)
    }
}
