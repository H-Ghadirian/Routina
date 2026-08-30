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
    func learnedTieBreakOrdersOtherwiseEqualCandidates() {
        let first = makeReadyTask(name: "Alpha")
        let second = makeReadyTask(name: "Beta")
        first.taskChoiceTieBreakScore = 0.2
        second.taskChoiceTieBreakScore = 0.1

        let ranked = TaskChoiceCandidateRanking.ranked(
            tasks: [second, first],
            condition: TaskChoiceCondition()
        )

        #expect(ranked.map(\.id) == [first.id, second.id])
    }

    @Test
    func nextComparisonUsesTheRemainingEqualTieBreak() throws {
        let alpha = makeReadyTask(name: "Alpha")
        let beta = makeReadyTask(name: "Beta")
        let gamma = makeReadyTask(name: "Gamma")
        alpha.taskChoiceTieBreakScore = 0.1
        gamma.taskChoiceTieBreakScore = 0.1

        let pair = try #require(TaskChoiceCandidateRanking.nextComparisonPair(
            tasks: [alpha, beta, gamma],
            condition: TaskChoiceCondition()
        ))

        #expect(Set([pair.0.id, pair.1.id]) == Set([alpha.id, gamma.id]))
    }

    @Test
    func missingDataCountsEveryRequiredTaskField() {
        let readyTask = makeReadyTask(name: "Ready")
        let missingTask = RoutineTask(name: "Missing")

        let missingData = TaskChoiceCandidateRanking.missingData(for: [readyTask, missingTask])

        #expect(missingData.importanceCount == 1)
        #expect(missingData.urgencyCount == 1)
        #expect(missingData.pressureCount == 1)
        #expect(missingData.thinkingNeededCount == 1)
        #expect(missingData.estimatedDurationCount == 1)
    }

    @Test
    func completedOneOffIsNeverSelectableForTaskChoice() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let completedOneOff = RoutineTask(
            name: "Completed once",
            scheduleMode: .oneOff,
            lastDone: Date(timeIntervalSince1970: 1)
        )

        #expect(!TaskChoiceCandidateRanking.isCurrentlySelectable(
            completedOneOff,
            referenceDate: now,
            calendar: calendar
        ))
    }

    @Test
    func archivedOneOffIsNeverSelectableForTaskChoice() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let archivedOneOff = RoutineTask(
            name: "Archive paperwork",
            scheduleMode: .oneOff,
            pausedAt: now
        )

        #expect(!TaskChoiceCandidateRanking.isCurrentlySelectable(
            archivedOneOff,
            referenceDate: now,
            calendar: calendar
        ))
    }

    @Test
    func pausedRepeatingTaskIsNeverSelectableForTaskChoice() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let pausedRoutine = RoutineTask(
            name: "Archive weekly review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 2, at: nil),
            pausedAt: now
        )

        #expect(!TaskChoiceCandidateRanking.isCurrentlySelectable(
            pausedRoutine,
            referenceDate: now,
            calendar: calendar
        ))
    }

    @Test
    func assumedDoneRepeatingTaskIsNeverSelectableForTaskChoice() {
        let now = Date(timeIntervalSince1970: 1_772_056_800)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let assumedDone = RoutineTask(
            name: "Daily review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            createdAt: Date(timeIntervalSince1970: 1_771_545_600),
            autoAssumeDailyDone: true
        )

        #expect(!TaskChoiceCandidateRanking.isCurrentlySelectable(
            assumedDone,
            referenceDate: now,
            calendar: calendar
        ))
    }

    @Test
    func missedAssumedOccurrenceIsSelectableForTaskChoiceAgain() {
        let now = Date(timeIntervalSince1970: 1_772_056_800)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let task = RoutineTask(
            name: "Daily review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            createdAt: Date(timeIntervalSince1970: 1_771_545_600),
            autoAssumeDailyDone: true
        )
        let missedLog = RoutineLog(
            timestamp: now,
            taskID: task.id,
            kind: .missed
        )

        #expect(TaskChoiceCandidateRanking.isCurrentlySelectable(
            task,
            referenceDate: now,
            calendar: calendar,
            logs: [missedLog]
        ))
    }

    @Test
    func assumedDoneTaskIsExcludedBeforeTaskChoiceReadinessAndRanking() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_772_056_800)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let assumedDone = RoutineTask(
            name: "Daily review",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0)),
            createdAt: Date(timeIntervalSince1970: 1_771_545_600),
            autoAssumeDailyDone: true
        )
        let readyTask = makeReadyTask(name: "Write proposal")
        context.insert(assumedDone)
        context.insert(readyTask)
        try context.save()

        let readyCandidate = TaskChoiceCandidate(task: readyTask)
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
        await store.receive(.tasksLoaded(.recommendation(readyCandidate, candidateCount: 1))) {
            $0.phase = .recommendation
            $0.recommendedTask = readyCandidate
            $0.candidateCount = 1
        }
    }

    @Test
    func unresolvedRequiredTaskIsSkippedBeforeReadinessAndRanking() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let prerequisite = makeReadyTask(name: "Renew passport")
        let blockedTask = RoutineTask(
            name: "Book flight",
            relationships: [
                RoutineTaskRelationship(
                    targetTaskID: prerequisite.id,
                    kind: .blockedBy
                )
            ]
        )
        context.insert(prerequisite)
        context.insert(blockedTask)
        try context.save()

        let prerequisiteCandidate = TaskChoiceCandidate(task: prerequisite)
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
        await store.receive(.tasksLoaded(.recommendation(prerequisiteCandidate, candidateCount: 1))) {
            $0.phase = .recommendation
            $0.recommendedTask = prerequisiteCandidate
            $0.candidateCount = 1
        }
    }

    @Test
    func completedRequirementAllowsDependentTaskIntoRanking() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let prerequisite = RoutineTask(
            name: "Renew passport",
            scheduleMode: .oneOff,
            lastDone: Date(timeIntervalSince1970: 1)
        )
        let dependent = makeReadyTask(name: "Book flight")
        dependent.replaceRelationships([
            RoutineTaskRelationship(
                targetTaskID: prerequisite.id,
                kind: .blockedBy
            )
        ])
        context.insert(prerequisite)
        context.insert(dependent)
        try context.save()

        let dependentCandidate = TaskChoiceCandidate(task: dependent)
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
        await store.receive(.tasksLoaded(.recommendation(dependentCandidate, candidateCount: 1))) {
            $0.phase = .recommendation
            $0.recommendedTask = dependentCandidate
            $0.candidateCount = 1
        }
    }

    @Test
    func pausedRepeatingRequirementStaysResolvedForCurrentChainStep() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let prerequisite = makeReadyTask(name: "Run Test.io")
        prerequisite.lastDone = now.addingTimeInterval(-86_400)
        prerequisite.pausedAt = now
        let dependent = makeReadyTask(name: "Release Candidate 4.4.0")
        dependent.lastDone = now.addingTimeInterval(-172_800)
        dependent.replaceRelationships([
            RoutineTaskRelationship(
                targetTaskID: prerequisite.id,
                kind: .blockedBy
            )
        ])
        context.insert(prerequisite)
        context.insert(dependent)
        try context.save()

        let dependentCandidate = TaskChoiceCandidate(task: dependent)
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
        await store.receive(.tasksLoaded(.recommendation(dependentCandidate, candidateCount: 1))) {
            $0.phase = .recommendation
            $0.recommendedTask = dependentCandidate
            $0.candidateCount = 1
        }
    }

    @Test
    func savesComparisonsAndOnlyRecommendsAfterAllTiesAreResolved() async throws {
        let context = makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let alpha = makeReadyTask(name: "Alpha")
        let beta = makeReadyTask(name: "Beta")
        let gamma = makeReadyTask(name: "Gamma")
        context.insert(alpha)
        context.insert(beta)
        context.insert(gamma)
        try context.save()

        let alphaCandidate = TaskChoiceCandidate(task: alpha)
        let betaCandidate = TaskChoiceCandidate(task: beta)
        let gammaCandidate = TaskChoiceCandidate(task: gamma)
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
        await store.receive(.tasksLoaded(.comparison(alphaCandidate, betaCandidate, candidateCount: 3))) {
            $0.phase = .comparing
            $0.firstCandidate = alphaCandidate
            $0.secondCandidate = betaCandidate
            $0.candidateCount = 3
        }

        await store.send(.preferredTaskSelected(alpha.id)) {
            $0.isSavingSelection = true
        }
        await store.receive(\.comparisonSaved) {
            $0.firstCandidate = TaskChoiceCandidate(task: alpha)
            $0.secondCandidate = nil
            $0.completedComparisonCount = 1
            $0.isSavingSelection = false
        }
        let savedAlpha = TaskChoiceCandidate(task: alpha)
        let comparedBeta = TaskChoiceCandidate(task: beta)
        await store.receive(.tasksLoaded(.comparison(gammaCandidate, comparedBeta, candidateCount: 3))) {
            $0.firstCandidate = gammaCandidate
            $0.secondCandidate = comparedBeta
        }

        await store.send(.preferredTaskSelected(gamma.id)) {
            $0.isSavingSelection = true
        }
        await store.receive(\.comparisonSaved) {
            $0.firstCandidate = TaskChoiceCandidate(task: gamma)
            $0.secondCandidate = nil
            $0.completedComparisonCount = 2
            $0.isSavingSelection = false
        }
        let savedGamma = TaskChoiceCandidate(task: gamma)
        await store.receive(.tasksLoaded(.comparison(savedAlpha, savedGamma, candidateCount: 3))) {
            $0.firstCandidate = savedAlpha
            $0.secondCandidate = savedGamma
        }

        await store.send(.preferredTaskSelected(alpha.id)) {
            $0.isSavingSelection = true
        }
        await store.receive(\.comparisonSaved) {
            $0.firstCandidate = TaskChoiceCandidate(task: alpha)
            $0.secondCandidate = nil
            $0.completedComparisonCount = 3
            $0.isSavingSelection = false
        }
        let resolvedAlpha = TaskChoiceCandidate(task: alpha)
        await store.receive(.tasksLoaded(.recommendation(resolvedAlpha, candidateCount: 3))) {
            $0.phase = .recommendation
            $0.recommendedTask = resolvedAlpha
        }

        #expect(alpha.taskChoiceTieBreakScore == 0.2)
        #expect(beta.taskChoiceTieBreakScore == 0)
        #expect(gamma.taskChoiceTieBreakScore == 0.1)
        #expect(alpha.taskChoiceComparisonCount == 2)
        #expect(beta.taskChoiceComparisonCount == 2)
        #expect(gamma.taskChoiceComparisonCount == 2)
    }

    @Test
    func detailsRequestAndRestartAreReducerOwned() async {
        let taskID = UUID()
        let task = TaskChoiceCandidate(task: makeReadyTask(name: "Compare me"))
        let store = TestStore(
            initialState: TaskChoiceFeature.State(
                phase: .recommendation,
                recommendedTask: task,
                candidateCount: 1
            )
        ) {
            TaskChoiceFeature()
        }

        await store.send(.taskDetailsTapped(taskID))
        await store.receive(.delegate(.taskDetailsRequested(taskID)))

        await store.send(.startAgainTapped) {
            $0.phase = .setup
            $0.recommendedTask = nil
            $0.candidateCount = 0
        }
    }

    @Test
    func iOSViewKeepsQueriesOutOfTheRenderPath() throws {
        let featureSource = try Self.sourceFile("SharedCore/Features/TaskChoice/TaskChoiceFeature.swift")
        let viewSource = try Self.sourceFile("iOS/Screens/More/TaskChoiceView.swift")

        #expect(featureSource.contains("TaskChoiceCandidateRanking.nextComparisonPair"))
        #expect(featureSource.contains("TaskChoiceCandidateRanking.missingData"))
        #expect(featureSource.contains("taskChoiceTieBreakScore"))
        #expect(!featureSource.contains("TaskChoiceTagPreference"))
        #expect(featureSource.contains("isCurrentlySelectable"))
        #expect(viewSource.contains("let store: StoreOf<TaskChoiceFeature>"))
        #expect(viewSource.contains("store.send(.preferredTaskSelected"))
        #expect(viewSource.contains("store.send(.taskDetailsTapped"))
        #expect(!viewSource.contains("@Query"))
        #expect(!viewSource.contains("@Environment(\\.modelContext)"))
        #expect(!viewSource.contains("modelContext.save()"))
    }

    private func makeReadyTask(name: String, tags: [String] = []) -> RoutineTask {
        RoutineTask(
            name: name,
            importance: .level2,
            urgency: .level2,
            pressure: .medium,
            thinkingNeeded: .medium,
            tags: tags,
            estimatedDurationMinutes: 30,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
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
