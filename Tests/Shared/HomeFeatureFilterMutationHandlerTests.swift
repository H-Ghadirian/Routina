import ComposableArchitecture
import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeFeatureFilterMutationHandlerTests {
    @Test
    func taskFilterMutation_persistsStateWhenFilterChanges() {
        var state = TestFilterMutationState()
        let recorder = TestFilterMutationRecorder()
        let handler = makeHandler(recorder)

        _ = handler.applyTaskFilterMutation(.selectedTag("Focus"), state: &state)

        #expect(state.taskFilters.selectedTag == "Focus")
        #expect(state.taskFilters.effectiveSelectedTags == ["Focus"])
        #expect(recorder.persistedStates.map(\.taskFilters.selectedTag) == ["Focus"])
        #expect(recorder.hiddenPreferenceWrites.isEmpty)
    }

    @Test
    func taskFilterMutation_skipsPersistenceForSheetPresentationOnly() {
        var state = TestFilterMutationState()
        let recorder = TestFilterMutationRecorder()
        let handler = makeHandler(recorder)

        _ = handler.applyTaskFilterMutation(.isFilterSheetPresented(true), state: &state)

        #expect(state.taskFilters.isFilterSheetPresented)
        #expect(recorder.persistedStates.isEmpty)
        #expect(recorder.hiddenPreferenceWrites.isEmpty)
    }

    @Test
    func taskFilterMutation_resetsHiddenPreferenceThroughInjectedClient() {
        var state = TestFilterMutationState(
            taskFilters: HomeTaskFiltersState(
                selectedTag: "Focus",
                selectedTags: ["Focus"],
                excludedTags: ["Admin"],
                selectedPressureFilter: .high
            ),
            hideUnavailableRoutines: true
        )
        let recorder = TestFilterMutationRecorder()
        let handler = makeHandler(recorder)

        _ = handler.applyTaskFilterMutation(.clearOptionalFilters, state: &state)

        #expect(!state.hideUnavailableRoutines)
        #expect(state.taskFilters.effectiveSelectedTags.isEmpty)
        #expect(state.taskFilters.excludedTags.isEmpty)
        #expect(state.taskFilters.selectedPressureFilter == nil)
        #expect(recorder.hiddenPreferenceWrites == [false])
        #expect(recorder.persistedStates.map(\.hideUnavailableRoutines) == [false])
    }

    @Test
    func timelineAndStatsMutationsPersistThroughInjectedCallback() {
        var state = TestFilterMutationState()
        let recorder = TestFilterMutationRecorder()
        let handler = makeHandler(recorder)

        _ = handler.applyTimelineFilterMutation(.selectedTags(["Focus"]), state: &state)
        _ = handler.applyStatsFilterMutation(.selectedTags(["Health"]), state: &state)

        #expect(state.timelineFilters.effectiveSelectedTags == ["Focus"])
        #expect(state.statsFilters.effectiveSelectedTags == ["Health"])
        #expect(recorder.persistedStates.map(\.timelineFilters.effectiveSelectedTags) == [["Focus"], ["Focus"]])
        #expect(recorder.persistedStates.map(\.statsFilters.effectiveSelectedTags) == [[], ["Health"]])
        #expect(recorder.hiddenPreferenceWrites.isEmpty)
    }

    @Test
    func validateFilterStatePrunesUnavailableTagsAndPlaces() {
        let missingPlaceID = UUID()
        var state = TestFilterMutationState(
            taskFilters: HomeTaskFiltersState(
                selectedTag: "Missing",
                selectedTags: ["Missing", "Focus"],
                excludedTags: ["Gone", "Admin"],
                selectedManualPlaceFilterID: missingPlaceID
            ),
            routineDisplays: [
                TestFilterRoutineDisplay(name: "Write", tags: ["Focus", "Admin"])
            ],
            routinePlaces: []
        )
        let recorder = TestFilterMutationRecorder()
        let handler = makeHandler(recorder)

        handler.validateFilterState(&state)

        #expect(state.taskFilters.effectiveSelectedTags == ["Focus"])
        #expect(state.taskFilters.excludedTags == ["Admin"])
        #expect(state.taskFilters.selectedManualPlaceFilterID == nil)
        #expect(recorder.persistedStates.isEmpty)
        #expect(recorder.hiddenPreferenceWrites.isEmpty)
    }

    private func makeHandler(_ recorder: TestFilterMutationRecorder) -> HomeFeatureFilterMutationHandler<TestFilterMutationState, Never> {
        HomeFeatureFilterMutationHandler(
            setHideUnavailableRoutines: { recorder.hiddenPreferenceWrites.append($0) },
            persistTemporaryViewState: { recorder.persistedStates.append($0) }
        )
    }
}

private final class TestFilterMutationRecorder {
    var hiddenPreferenceWrites: [Bool] = []
    var persistedStates: [TestFilterMutationState] = []
}

private struct TestFilterMutationState: HomeFeatureFilterMutationState, Equatable {
    var taskFilters = HomeTaskFiltersState()
    var timelineFilters = HomeTimelineFiltersState()
    var statsFilters = HomeStatsFiltersState()
    var hideUnavailableRoutines = false
    var routineDisplays: [TestFilterRoutineDisplay] = []
    var awayRoutineDisplays: [TestFilterRoutineDisplay] = []
    var archivedRoutineDisplays: [TestFilterRoutineDisplay] = []
    var routinePlaces: [RoutinePlace] = []
}

private struct TestFilterRoutineDisplay: HomeTaskListDisplay, Equatable {
    var taskID = UUID()
    var name: String
    var emoji = "✅"
    var notes: String?
    var placeID: UUID?
    var placeName: String?
    var tags: [String] = []
    var goalTitles: [String] = []
    var interval = 7
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
    var daysUntilDue = 7
    var isOneOffTask = false
    var isCompletedOneOff = false
    var isCanceledOneOff = false
    var isDoneToday = false
    var isPaused = false
    var isPinned = false
    var isInProgress = false
    var completedChecklistItemCount = 0
    var manualSectionOrders: [String: Int] = [:]
    var todoState: TodoState?
}
