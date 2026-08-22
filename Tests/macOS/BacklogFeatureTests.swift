import ComposableArchitecture
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
            $0.modelContext = { context }
        }

        await store.send(.automaticRefresh)
        await store.receive(.tasksLoaded([], [], []))
    }

    @Test
    func manualRefreshStillUsesVisibleLoadingState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: BacklogFeature.State()) {
            BacklogFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }
        await store.receive(.tasksLoaded([], [], [])) {
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
}
