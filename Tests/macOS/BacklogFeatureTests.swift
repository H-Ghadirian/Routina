import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct BacklogFeatureTests {
    @Test
    func searchTextRebuildsTheCachedBacklogPresentation() async {
        let sectionID = UUID()
        let matchingTask = RoutineTask(name: "Renew passport", customTaskSectionID: sectionID)
        let hiddenTask = RoutineTask(name: "Plan balcony", customTaskSectionID: sectionID)
        let section = HomeCustomTaskSection(
            id: sectionID,
            surface: .backlog,
            title: "Someday",
            createdAt: nil
        )
        var initialState = BacklogFeature.State()
        initialState.tasks = [matchingTask, hiddenTask]
        initialState.customSections = [section]
        initialState.presentation = BacklogTaskListPresentation.make(
            tasks: initialState.tasks,
            customSections: initialState.customSections,
            flagRules: [],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )
        let store = TestStore(initialState: initialState) {
            BacklogFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.date.now = Date(timeIntervalSince1970: 1_000)
        }

        await store.send(.searchTextChanged("passport")) {
            $0.searchText = "passport"
            $0.presentation = BacklogTaskListPresentation.make(
                tasks: $0.tasks,
                customSections: $0.customSections,
                flagRules: [],
                searchText: "passport",
                referenceDate: Date(timeIntervalSince1970: 1_000),
                calendar: Calendar(identifier: .gregorian)
            )
        }

        #expect(store.state.presentation.sections.first?.tasks.map(\.id) == [matchingTask.id])
    }

    @Test
    func automaticRefreshDoesNotEnterVisibleLoadingState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: BacklogFeature.State()) {
            BacklogFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
        }

        await store.send(.automaticRefresh)
        await store.receive(.tasksLoaded([], [], [], [], [], [:]))
    }

    @Test
    func manualRefreshStillUsesVisibleLoadingState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: BacklogFeature.State()) {
            BacklogFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }
        await store.receive(.tasksLoaded([], [], [], [], [], [:])) {
            $0.isLoading = false
        }
    }

    @Test
    func deactivatingWorkspaceClearsEmbeddedTaskDetailBeforeLayoutChanges() async {
        let task = RoutineTask(name: "Read mail", scheduleMode: .oneOff)
        var initialState = BacklogFeature.State()
        initialState.tasks = [task]
        initialState.selectedTaskID = task.id
        initialState.taskDetailState = HomeTaskSupport.makeTaskDetailState(
            for: task,
            now: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )
        let store = TestStore(initialState: initialState) {
            BacklogFeature()
        }

        await store.send(.workspaceDeactivated) {
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
        }
    }

    @Test
    func workspaceSwitchPreservesBacklogDisclosureChoices() async {
        let superSectionID = UUID()
        let subsectionID = UUID()
        let store = TestStore(initialState: BacklogFeature.State()) {
            BacklogFeature()
        }

        await store.send(.superSectionDisclosureToggled(superSectionID)) {
            $0.collapsedSuperSectionIDs = [superSectionID]
        }
        await store.send(.subsectionDisclosureToggled(subsectionID)) {
            $0.collapsedSubsectionIDs = [subsectionID]
        }

        await store.send(.workspaceDeactivated)

        #expect(store.state.collapsedSuperSectionIDs == [superSectionID])
        #expect(store.state.collapsedSubsectionIDs == [subsectionID])
    }

    @Test
    func searchExpansionDoesNotMutateBacklogDisclosureChoices() async {
        let superSectionID = UUID()
        let subsectionID = UUID()
        var initialState = BacklogFeature.State()
        initialState.searchText = "mail"
        initialState.collapsedSuperSectionIDs = [superSectionID]
        initialState.collapsedSubsectionIDs = [subsectionID]
        let store = TestStore(initialState: initialState) {
            BacklogFeature()
        }

        await store.send(.superSectionDisclosureToggled(superSectionID))
        await store.send(.subsectionDisclosureToggled(subsectionID))

        #expect(store.state.collapsedSuperSectionIDs == [superSectionID])
        #expect(store.state.collapsedSubsectionIDs == [subsectionID])
    }

    @Test
    func filterChangesRebuildTheCachedBacklogPresentationWithoutChangingSearch() async {
        let sectionID = UUID()
        let emptySectionID = UUID()
        let oneOff = RoutineTask(
            name: "Renew passport",
            customTaskSectionID: sectionID,
            scheduleMode: .oneOff
        )
        let repeating = RoutineTask(
            name: "Read weekly",
            customTaskSectionID: sectionID
        )
        let section = HomeCustomTaskSection(
            id: sectionID,
            surface: .backlog,
            title: "Someday",
            createdAt: nil
        )
        let emptySection = HomeCustomTaskSection(
            id: emptySectionID,
            surface: .backlog,
            title: "Empty",
            createdAt: nil
        )
        var initialState = BacklogFeature.State()
        initialState.tasks = [oneOff, repeating]
        initialState.customSections = [section, emptySection]
        initialState.presentation = BacklogTaskListPresentation.make(
            tasks: initialState.tasks,
            customSections: initialState.customSections,
            flagRules: [],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: Calendar(identifier: .gregorian)
        )
        let store = TestStore(initialState: initialState) {
            BacklogFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.date.now = Date(timeIntervalSince1970: 1_000)
        }
        var filters = BacklogFilterState.default
        filters.taskListMode = .todos
        filters.sortOrder = .dueSoonestFirst

        await store.send(.filtersChanged(filters)) {
            $0.filters = filters
            $0.presentation = BacklogTaskListPresentation.make(
                tasks: $0.tasks,
                customSections: $0.customSections,
                flagRules: [],
                filters: filters,
                referenceDate: Date(timeIntervalSince1970: 1_000),
                calendar: Calendar(identifier: .gregorian)
            )
        }

        #expect(store.state.presentation.sections.first?.tasks.map(\.id) == [oneOff.id])
        #expect(store.state.presentation.sections.map(\.id) == [sectionID])
        #expect(store.state.searchText.isEmpty)

        await store.send(.clearFilters) {
            $0.filters = .default
            $0.presentation = BacklogTaskListPresentation.make(
                tasks: $0.tasks,
                customSections: $0.customSections,
                flagRules: [],
                referenceDate: Date(timeIntervalSince1970: 1_000),
                calendar: Calendar(identifier: .gregorian)
            )
        }

        #expect(store.state.presentation.sections.map(\.id) == [sectionID, emptySectionID])
    }

    @Test
    func planTaskUpdatesBacklogAndPersistsWithoutChangingItsSection() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let requestedDate = Date(timeIntervalSince1970: 200_000)
        let expectedDate = calendar.startOfDay(for: requestedDate)
        let sectionID = UUID()
        let task = RoutineTask(
            name: "Read someday",
            customTaskSectionID: sectionID,
            scheduleMode: .oneOff
        )
        let context = makeInMemoryContext()
        context.insert(task)
        try context.save()
        let section = HomeCustomTaskSection(
            id: sectionID,
            surface: .backlog,
            title: "Someday",
            createdAt: nil
        )
        var initialState = BacklogFeature.State()
        initialState.tasks = [task.detachedCopy()]
        initialState.customSections = [section]
        initialState.selectedTaskID = task.id
        initialState.taskDetailState = HomeTaskSupport.makeTaskDetailState(
            for: task,
            now: referenceDate,
            calendar: calendar
        )
        initialState.presentation = BacklogTaskListPresentation.make(
            tasks: initialState.tasks,
            customSections: initialState.customSections,
            flagRules: [],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let store = TestStore(initialState: initialState) {
            BacklogFeature()
        } withDependencies: {
            $0.calendar = calendar
            $0.date.now = referenceDate
            $0.modelContext = { context }
        }

        await store.send(.planTask(task.id, requestedDate)) {
            $0.tasks[0].plannedDate = expectedDate
            $0.taskDetailState?.task.plannedDate = expectedDate
            $0.taskDetailState?.taskRefreshID = 1
            $0.presentation = BacklogTaskListPresentation.make(
                tasks: $0.tasks,
                customSections: $0.customSections,
                flagRules: [],
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        await store.finish()

        let persistedTask = try #require(
            context.fetch(HomeTaskSupport.taskDescriptor(for: task.id)).first
        )
        #expect(persistedTask.plannedDate == expectedDate)
        #expect(persistedTask.customTaskSectionID == sectionID)
        #expect(store.state.presentation.sections.first?.tasks.map(\.id) == [task.id])
    }
}
