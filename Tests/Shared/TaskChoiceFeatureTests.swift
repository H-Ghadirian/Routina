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
struct TaskChoiceFeatureTests {
    @Test
    func shortlist_prefersComparableTasksForTheFirstPair() {
        let seed = makeCandidate(
            name: "Critical proposal",
            importance: .level4,
            urgency: .level4,
            pressure: .high,
            thinkingNeeded: .medium,
            estimatedDurationMinutes: 30
        )
        let comparableTask = makeCandidate(
            name: "Comparable proposal",
            importance: .level4,
            urgency: .level4,
            pressure: .high,
            thinkingNeeded: .medium,
            estimatedDurationMinutes: 60
        )
        let higherScoredButDifferentTask = makeCandidate(
            name: "Different task",
            importance: .level4,
            urgency: .level4,
            pressure: .high,
            thinkingNeeded: .high,
            estimatedDurationMinutes: 15
        )

        let shortlist = TaskChoiceCandidateRanking.shortlist(
            tasks: [seed, comparableTask, higherScoredButDifferentTask],
            condition: TaskChoiceCondition(
                availableTime: .thirtyMinutes,
                energy: .medium,
                intent: .makeProgress
            )
        )

        #expect(shortlist.map(\.id) == [seed.id, comparableTask.id, higherScoredButDifferentTask.id])
    }

    @Test
    func lowEnergyAndShortTimePenalizeHighThinkingAndLongTasks() {
        let suitableTask = TaskChoiceCandidate(task: makeCandidate(
            name: "Quick admin",
            importance: .level2,
            urgency: .level2,
            pressure: .low,
            thinkingNeeded: .low,
            estimatedDurationMinutes: 15
        ))
        let unsuitableTask = TaskChoiceCandidate(task: makeCandidate(
            name: "Complex strategy",
            importance: .level2,
            urgency: .level2,
            pressure: .low,
            thinkingNeeded: .high,
            estimatedDurationMinutes: 90
        ))
        let condition = TaskChoiceCondition(
            availableTime: .fifteenMinutes,
            energy: .low,
            intent: .makeProgress
        )

        #expect(
            TaskChoiceCandidateRanking.score(suitableTask, for: condition)
                > TaskChoiceCandidateRanking.score(unsuitableTask, for: condition)
        )
    }

    @Test
    func loadsBoundedEligibleCandidatesAndUsesPairwiseWinnerSelection() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstTask = makeTask(in: context, name: "Alpha", interval: 1, lastDone: nil, emoji: nil)
        let secondTask = makeTask(in: context, name: "Beta", interval: 1, lastDone: nil, emoji: nil)
        let thirdTask = makeTask(in: context, name: "Gamma", interval: 1, lastDone: nil, emoji: nil)
        let completedOneOff = makeTask(
            in: context,
            name: "Completed todo",
            interval: 1,
            lastDone: Date(timeIntervalSince1970: 1),
            emoji: nil,
            scheduleMode: .oneOff
        )
        let completedRoutine = makeTask(
            in: context,
            name: "Completed routine",
            interval: 1,
            lastDone: now,
            emoji: nil
        )
        let canceledTask = makeTask(in: context, name: "Canceled", interval: 1, lastDone: nil, emoji: nil)
        canceledTask.canceledAt = Date(timeIntervalSince1970: 1)
        let pausedTask = makeTask(
            in: context,
            name: "Paused",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            pausedAt: now
        )
        try context.save()

        let condition = TaskChoiceCondition()
        let expectedCandidates = TaskChoiceCandidateRanking.shortlist(
            tasks: [firstTask, secondTask, thirdTask],
            condition: condition
        )
        let store = TestStore(initialState: TaskChoiceFeature.State()) {
            TaskChoiceFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = now
            $0.calendar = calendar
        }

        await store.send(.findTasksTapped) {
            $0.phase = .loading
        }
        await store.receive(.candidatesLoaded(expectedCandidates)) {
            $0.candidates = expectedCandidates
            $0.currentWinner = expectedCandidates.first
            $0.phase = .comparing
        }

        #expect(!store.state.candidates.contains(where: { $0.id == completedOneOff.id }))
        #expect(!store.state.candidates.contains(where: { $0.id == completedRoutine.id }))
        #expect(!store.state.candidates.contains(where: { $0.id == canceledTask.id }))
        #expect(!store.state.candidates.contains(where: { $0.id == pausedTask.id }))
        #expect(store.state.candidates.count <= TaskChoiceCandidateRanking.maximumCandidateCount)

        let challenger = try #require(store.state.currentChallenger)
        let firstWinner = try #require(store.state.currentWinner)
        await store.send(.preferredTaskSelected(challenger.id)) {
            $0.currentWinner = challenger
            $0.nextCandidateIndex = 2
            $0.alternatives = [firstWinner]
        }

        let finalChallenger = try #require(store.state.currentChallenger)
        await store.send(.preferredTaskSelected(challenger.id)) {
            $0.nextCandidateIndex = 3
            $0.alternatives = [firstWinner, finalChallenger]
            $0.phase = .recommendation
        }
    }

    @Test
    func detailsRequestAndRestartAreReducerOwned() async {
        let taskID = UUID()
        let task = TaskChoiceCandidate(task: makeCandidate(name: "Compare me"))
        let store = TestStore(
            initialState: TaskChoiceFeature.State(
                phase: .recommendation,
                candidates: [task],
                currentWinner: task
            )
        ) {
            TaskChoiceFeature()
        }

        await store.send(.taskDetailsTapped(taskID))
        await store.receive(.delegate(.taskDetailsRequested(taskID)))

        await store.send(.startAgainTapped) {
            $0.phase = .setup
            $0.candidates = []
            $0.currentWinner = nil
            $0.nextCandidateIndex = 1
        }
    }

    @Test
    func iOSViewKeepsQueriesOutOfTheRenderPath() throws {
        let featureSource = try Self.sourceFile("SharedCore/Features/TaskChoice/TaskChoiceFeature.swift")
        let viewSource = try Self.sourceFile("iOS/Screens/More/TaskChoiceView.swift")
        let appSource = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        #expect(featureSource.contains("maximumCandidateCount = 6"))
        #expect(featureSource.contains("TaskChoiceCandidateRanking.shortlist"))
        #expect(featureSource.contains("isCurrentlySelectable"))
        #expect(viewSource.contains("let store: StoreOf<TaskChoiceFeature>"))
        #expect(viewSource.contains("store.send(.preferredTaskSelected"))
        #expect(viewSource.contains("store.send(.taskDetailsTapped"))
        #expect(!viewSource.contains("@Query"))
        #expect(!viewSource.contains("@Environment(\\.modelContext)"))
        #expect(!viewSource.contains("modelContext.save()"))
        #expect(appSource.contains("title: \"Help me choose\""))
        #expect(appSource.contains("TaskChoiceView(store: taskChoiceStore)"))
    }

    private func makeCandidate(
        name: String,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        pressure: RoutineTaskPressure = .none,
        thinkingNeeded: RoutineTaskThinkingNeeded = .none,
        estimatedDurationMinutes: Int? = nil
    ) -> RoutineTask {
        let task = RoutineTask(name: name, estimatedDurationMinutes: estimatedDurationMinutes)
        task.importance = importance
        task.urgency = urgency
        task.pressure = pressure
        task.thinkingNeeded = thinkingNeeded
        return task
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
