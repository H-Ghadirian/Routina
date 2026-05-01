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
        await store.receive(.goalsLoaded(expectedGoals)) {
            $0.goals = expectedGoals
            $0.isLoading = false
            $0.selectedGoalID = goal.id
        }
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
        await store.send(.saveEditorTapped)
        await store.receive(.goalSaved) {
            $0.isEditorPresented = false
            $0.validationMessage = nil
        }

        let savedGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let goal = try #require(savedGoals.first)
        let expectedGoals = GoalsFeature.GoalDisplay.displays(
            goals: savedGoals,
            tasks: [],
            referenceDate: now,
            calendar: calendar
        )
        await store.receive(.goalsLoaded(expectedGoals)) {
            $0.goals = expectedGoals
            $0.selectedGoalID = goal.id
        }

        #expect(savedGoals.count == 1)
        #expect(goal.title == "Launch MVP")
        #expect(goal.emoji == "L")
        #expect(goal.notes == "Ship a usable first version.")
        #expect(goal.targetDate == targetDate)
        #expect(goal.color == .blue)
    }

    @Test
    func deleteGoalConfirmed_removesGoalAndTaskLinks() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-05-01T09:00:00Z")
        let calendar = makeTestCalendar()
        let goal = RoutineGoal(title: "Portfolio", emoji: "P")
        context.insert(goal)
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
            goals: [goal],
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
        await store.receive(.goalsLoaded([])) {
            $0.goals = []
            $0.isLoading = false
            $0.selectedGoalID = nil
        }

        let remainingGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remainingGoals.isEmpty)
        #expect(remainingTasks.first?.goalIDs.isEmpty == true)
    }
}
