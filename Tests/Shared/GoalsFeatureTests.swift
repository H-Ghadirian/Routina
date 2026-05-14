import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
@Suite(.serialized)
struct GoalsFeatureTests {
    @Test
    func onAppear_loadsGoalsWithLinkedTasks() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let goal = RoutineGoal(
            title: "Health",
            emoji: "H",
            targetDate: makeDate("2026-06-01T09:00:00Z"),
            color: .green,
            createdAt: makeDate("2026-04-01T09:00:00Z")
        )
        context.insert(goal)
        let task = makeTask(
            in: context,
            name: "Run",
            interval: 2,
            lastDone: makeDate("2026-04-29T09:00:00Z"),
            emoji: "R",
            scheduleAnchor: makeDate("2026-04-29T09:00:00Z")
        )
        task.goalIDs = [goal.id]
        try context.save()

        let expectedGoals = GoalsFeature.GoalDisplay.displays(
            goals: [goal],
            tasks: [task],
            referenceDate: now,
            calendar: calendar
        )

        let store = TestStore(initialState: GoalsFeature.State()) {
            GoalsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.goalsLoaded(expectedGoals, [], [], .defaultValue, [:])) {
            $0.goals = expectedGoals
            $0.availableTags = []
            $0.isLoading = false
            $0.selectedGoalID = goal.id
        }
    }

    @Test
    func onAppear_loadsParentAndSubGoals() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let parent = RoutineGoal(title: "Health", emoji: "H", sortOrder: 0)
        let child = RoutineGoal(title: "Run 5K", emoji: "R", parentGoalID: parent.id, sortOrder: 1)
        context.insert(parent)
        context.insert(child)
        try context.save()

        let expectedGoals = GoalsFeature.GoalDisplay.displays(
            goals: [parent, child],
            tasks: [],
            referenceDate: now,
            calendar: calendar
        )

        let store = TestStore(initialState: GoalsFeature.State()) {
            GoalsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.goalsLoaded(expectedGoals, [], [], .defaultValue, [:])) {
            $0.goals = expectedGoals
            $0.availableTags = []
            $0.isLoading = false
            $0.selectedGoalID = parent.id
        }

        let loadedParent = try #require(store.state.goals.first { $0.id == parent.id })
        let loadedChild = try #require(store.state.goals.first { $0.id == child.id })
        #expect(loadedParent.childGoals.map(\.id) == [child.id])
        #expect(loadedChild.parentGoal?.id == parent.id)
    }

    @Test
    func saveEditorTapped_createsGoal() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let targetDate = try #require(calendar.date(byAdding: .month, value: 1, to: now))

        let store = TestStore(initialState: GoalsFeature.State()) {
            GoalsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }

        await store.send(.addGoalTapped) {
            $0.isEditorPresented = true
        }
        await store.send(.editorTitleChanged("Launch MVP")) {
            $0.editorDraft.title = "Launch MVP"
        }
        await store.send(.editorEmojiChanged("L")) {
            $0.editorDraft.emoji = "L"
        }
        await store.send(.editorNotesChanged("Ship a usable first version.")) {
            $0.editorDraft.notes = "Ship a usable first version."
        }
        await store.send(.editorTargetDateEnabledChanged(true)) {
            $0.editorDraft.targetDate = targetDate
        }
        await store.send(.editorColorChanged(.blue)) {
            $0.editorDraft.color = .blue
        }
        await store.send(.editorTagDraftChanged("Health, Work, health")) {
            $0.editorDraft.tagDraft = "Health, Work, health"
        }
        await store.send(.editorAddTagTapped) {
            $0.editorDraft.tags = ["Health", "Work"]
            $0.editorDraft.tagDraft = ""
        }
        await store.send(.saveEditorTapped)
        await store.receive(\.goalSaved) {
            let savedGoal = try #require(try context.fetch(FetchDescriptor<RoutineGoal>()).first)
            $0.isEditorPresented = false
            $0.validationMessage = nil
            $0.selectedGoalID = savedGoal.id
        }

        let savedGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let goal = try #require(savedGoals.first)
        let expectedGoals = GoalsFeature.GoalDisplay.displays(
            goals: savedGoals,
            tasks: [],
            referenceDate: now,
            calendar: calendar
        )
        let expectedTagSummaries = [
            RoutineTagSummary(name: "Health", linkedRoutineCount: 0, linkedGoalCount: 1),
            RoutineTagSummary(name: "Work", linkedRoutineCount: 0, linkedGoalCount: 1)
        ]
        let expectedRelatedTagRules = [
            RoutineRelatedTagRule(tag: "Health", relatedTags: ["Work"]),
            RoutineRelatedTagRule(tag: "Work", relatedTags: ["Health"])
        ]
        await store.receive(.goalsLoaded(expectedGoals, expectedTagSummaries, expectedRelatedTagRules, .defaultValue, [:])) {
            $0.goals = expectedGoals
            $0.availableTagSummaries = expectedTagSummaries
            $0.availableTags = ["Health", "Work"]
            $0.relatedTagRules = expectedRelatedTagRules
            $0.selectedGoalID = goal.id
        }

        #expect(savedGoals.count == 1)
        #expect(goal.title == "Launch MVP")
        #expect(goal.emoji == "L")
        #expect(goal.notes == "Ship a usable first version.")
        #expect(goal.targetDate == targetDate)
        #expect(goal.color == .blue)
        #expect(goal.tags == ["Health", "Work"])
    }

    @Test
    func editorAcceptTagAutocompleteTappedCompletesCurrentDraftToken() async {
        let store = TestStore(
            initialState: GoalsFeature.State(
                availableTags: ["Health", "Home", "Work"],
                isEditorPresented: true,
                editorDraft: GoalsFeature.GoalDraft(tags: ["Work"], tagDraft: "deep, ho")
            )
        ) {
            GoalsFeature()
        }

        await store.send(.editorAcceptTagAutocompleteTapped) {
            $0.editorDraft.tagDraft = "deep, Home"
        }
    }

    @Test
    func saveEditorTapped_linksGoalToParent() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let parent = RoutineGoal(title: "Health")
        context.insert(parent)
        try context.save()

        let store = TestStore(initialState: GoalsFeature.State()) {
            GoalsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }

        await store.send(.addGoalTapped) {
            $0.isEditorPresented = true
        }
        await store.send(.editorTitleChanged("Run 5K")) {
            $0.editorDraft.title = "Run 5K"
        }
        await store.send(.editorParentGoalChanged(parent.id)) {
            $0.editorDraft.parentGoalID = parent.id
        }
        await store.send(.saveEditorTapped)
        await store.receive(\.goalSaved) {
            let child = try #require(try context.fetch(FetchDescriptor<RoutineGoal>()).first { $0.title == "Run 5K" })
            $0.isEditorPresented = false
            $0.validationMessage = nil
            $0.selectedGoalID = child.id
        }

        let savedGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let child = try #require(savedGoals.first { $0.title == "Run 5K" })
        let expectedGoals = GoalsFeature.GoalDisplay.displays(
            goals: savedGoals,
            tasks: [],
            referenceDate: now,
            calendar: calendar
        )
        await store.receive(.goalsLoaded(expectedGoals, [], [], .defaultValue, [:])) {
            $0.goals = expectedGoals
            $0.availableTags = []
            $0.selectedGoalID = child.id
        }

        #expect(child.parentGoalID == parent.id)
    }

    @Test
    func saveEditorTapped_rejectsParentGoalCycle() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let parent = RoutineGoal(title: "Health", sortOrder: 0)
        let child = RoutineGoal(title: "Run 5K", parentGoalID: parent.id, sortOrder: 1)
        context.insert(parent)
        context.insert(child)
        try context.save()
        let displays = GoalsFeature.GoalDisplay.displays(
            goals: [parent, child],
            tasks: [],
            referenceDate: now,
            calendar: calendar
        )

        let store = TestStore(
            initialState: GoalsFeature.State(
                goals: displays,
                isEditorPresented: true,
                editorDraft: GoalsFeature.GoalDraft(goal: displays[0])
            )
        ) {
            GoalsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }

        await store.send(.editorParentGoalChanged(child.id)) {
            $0.editorDraft.parentGoalID = child.id
        }
        await store.send(.saveEditorTapped)
        await store.receive(.loadingFailed("Choose a different parent goal.")) {
            $0.isLoading = false
            $0.validationMessage = "Choose a different parent goal."
        }

        #expect(parent.parentGoalID == nil)
    }

    @Test
    func deleteGoalConfirmed_removesGoalAndTaskLinks() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let goal = RoutineGoal(title: "Portfolio", emoji: "P")
        context.insert(goal)
        let childGoal = RoutineGoal(title: "Case Study", parentGoalID: goal.id)
        context.insert(childGoal)
        let task = makeTask(
            in: context,
            name: "Write case study",
            interval: 7,
            lastDone: nil,
            emoji: "W"
        )
        task.goalIDs = [goal.id]
        try context.save()

        let initialGoals = GoalsFeature.GoalDisplay.displays(
            goals: [goal, childGoal],
            tasks: [task],
            referenceDate: now,
            calendar: calendar
        )

        let store = TestStore(
            initialState: GoalsFeature.State(
                goals: initialGoals,
                selectedGoalID: goal.id
            )
        ) {
            GoalsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
        }

        await store.send(.deleteGoalRequested(goal.id)) {
            $0.pendingDeleteGoalID = goal.id
        }
        await store.send(.deleteGoalConfirmed) {
            $0.pendingDeleteGoalID = nil
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
        }
        let remainingGoalDisplays = GoalsFeature.GoalDisplay.displays(
            goals: [childGoal],
            tasks: [task],
            referenceDate: now,
            calendar: calendar
        )
        await store.receive(.goalsLoaded(remainingGoalDisplays, [], [], .defaultValue, [:])) {
            $0.goals = remainingGoalDisplays
            $0.availableTags = []
            $0.isLoading = false
            $0.selectedGoalID = childGoal.id
        }

        let remainingGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remainingGoals.map(\.id) == [childGoal.id])
        #expect(remainingGoals.first?.parentGoalID == nil)
        #expect(remainingTasks.first?.goalIDs.isEmpty == true)
    }
}
