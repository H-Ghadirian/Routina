import Foundation
import SwiftData

struct RoutinaScreenshotDataSeedResult: Equatable, Sendable {
    var taskCount = 0
    var sectionCount = 0
    var logCount = 0
    var plannerBlockCount = 0
    var focusSessionCount = 0
    var goalCount = 0
    var noteCount = 0
    var eventCount = 0
    var sleepSessionCount = 0
    var awaySessionCount = 0
    var refreshedRecordCount = 0
    var removedRecordCount = 0
    var managedTaskCount = 0
    var managedSectionCount = 0
    var managedSupportingRecordCount = 0

    var totalInsertedCount: Int {
        taskCount
            + sectionCount
            + logCount
            + plannerBlockCount
            + focusSessionCount
            + goalCount
            + noteCount
            + eventCount
            + sleepSessionCount
            + awaySessionCount
    }

    var totalChangedCount: Int {
        totalInsertedCount + refreshedRecordCount + removedRecordCount
    }
}

enum RoutinaScreenshotDataSeeder {
    static let taskCount = 16
    static let retiredGoalIDs = Set((101..<104).map(seedID))
    static let retiredEventIDs = Set((0..<2).map { seedID(8_000 + $0) })
    static let retiredEmotionIDs = Set((0..<10).map { seedID(9_000 + $0) })

    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard AppEnvironment.isScreenshotDataSeedRequested else { return }

        do {
            let result = try seed(in: context)
            _ = RoutinaUserPreferencesStore.applyToDefaults(from: context)
            NSLog(
                "Routina screenshot data seed finished with \(result.totalInsertedCount) inserted, \(result.refreshedRecordCount) refreshed, and \(result.removedRecordCount) removed records."
            )
            if AppEnvironment.exitsAfterScreenshotDataSeed {
                Foundation.exit(EXIT_SUCCESS)
            }
        } catch {
            NSLog("Routina screenshot data seed failed: \(error.localizedDescription)")
            if AppEnvironment.exitsAfterScreenshotDataSeed {
                Foundation.exit(EXIT_FAILURE)
            }
        }
    }

    @MainActor
    static func seed(
        in context: ModelContext,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> RoutinaScreenshotDataSeedResult {
        let dates = SeedDates(referenceDate: referenceDate, calendar: calendar)
        let customSections = makeCustomSections(dates: dates)
        let goals: [RoutineGoal] = []
        let tasks = makeTasks(dates: dates, customSections: customSections)
        let logs = makeLogs(dates: dates, tasks: tasks)
        let plannerBlocks = makePlannerBlocks(dates: dates, tasks: tasks)
        let focusSessions = makeFocusSessions(dates: dates, tasks: tasks)
        let notes = makeNotes(dates: dates)
        let events: [RoutineEvent] = []
        let sleepSessions = makeSleepSessions(dates: dates)
        let awaySessions = makeAwaySessions(dates: dates, tasks: tasks)

        var result = RoutinaScreenshotDataSeedResult(
            managedTaskCount: tasks.count,
            managedSectionCount: customSections.count,
            managedSupportingRecordCount: logs.count
                + plannerBlocks.count
                + focusSessions.count
                + goals.count
                + notes.count
                + events.count
                + sleepSessions.count
                + awaySessions.count
        )

        try mergeCustomSections(
            customSections,
            updatedAt: referenceDate,
            in: context,
            result: &result
        )
        let existingGoals = try upsertGoals(goals, in: context, result: &result)
        try upsertTasks(tasks, in: context, result: &result)
        try upsertLogs(logs, in: context, result: &result)
        try upsertPlannerBlocks(plannerBlocks, in: context, result: &result)
        try upsertFocusSessions(focusSessions, in: context, result: &result)
        try upsertNotes(notes, in: context, result: &result)
        let existingEvents = try upsertEvents(events, in: context, result: &result)
        try upsertSleepSessions(sleepSessions, in: context, result: &result)
        try upsertAwaySessions(awaySessions, in: context, result: &result)
        try removeRetiredRecords(
            existingGoals: existingGoals,
            existingEvents: existingEvents,
            in: context,
            result: &result
        )

        if result.totalChangedCount > 0 {
            try context.save()
        }
        return result
    }
}
