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

        let preferences = try RoutinaUserPreferencesStore.fetchOrCreate(in: context)
        let existingSections = HomeCustomTaskSectionStorage.decoded(
            from: preferences.customTaskSections
        )
        var mergedSections = existingSections
        for section in customSections {
            if let index = mergedSections.firstIndex(where: { $0.id == section.id }) {
                mergedSections[index] = section
                result.refreshedRecordCount += 1
            } else {
                mergedSections.append(section)
                result.sectionCount += 1
            }
        }
        preferences.customTaskSections = HomeCustomTaskSectionStorage.encoded(mergedSections)
        preferences.updatedAt = referenceDate

        let existingGoals = Dictionary(
            try context.fetch(FetchDescriptor<RoutineGoal>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for goal in goals {
            if let existing = existingGoals[goal.id] {
                refresh(existing, from: goal)
                result.refreshedRecordCount += 1
            } else {
                context.insert(goal)
                result.goalCount += 1
            }
        }

        let existingTasks = Dictionary(
            try context.fetch(FetchDescriptor<RoutineTask>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for task in tasks {
            if let existing = existingTasks[task.id] {
                refresh(existing, from: task)
                result.refreshedRecordCount += 1
            } else {
                context.insert(task)
                result.taskCount += 1
            }
        }

        let existingLogs = Dictionary(
            try context.fetch(FetchDescriptor<RoutineLog>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for log in logs {
            if let existing = existingLogs[log.id] {
                refresh(existing, from: log)
                result.refreshedRecordCount += 1
            } else {
                context.insert(log)
                result.logCount += 1
            }
        }

        let existingPlannerBlocks = Dictionary(
            try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for block in plannerBlocks {
            if let existing = existingPlannerBlocks[block.id] {
                existing.apply(block.detachedBlock)
                result.refreshedRecordCount += 1
            } else {
                context.insert(block)
                result.plannerBlockCount += 1
            }
        }

        let existingFocusSessions = Dictionary(
            try context.fetch(FetchDescriptor<FocusSession>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for session in focusSessions {
            if let existing = existingFocusSessions[session.id] {
                refresh(existing, from: session)
                result.refreshedRecordCount += 1
            } else {
                context.insert(session)
                result.focusSessionCount += 1
            }
        }

        let existingNotes = Dictionary(
            try context.fetch(FetchDescriptor<RoutineNote>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for note in notes {
            if let existing = existingNotes[note.id] {
                refresh(existing, from: note)
                result.refreshedRecordCount += 1
            } else {
                context.insert(note)
                result.noteCount += 1
            }
        }

        let existingEvents = Dictionary(
            try context.fetch(FetchDescriptor<RoutineEvent>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for event in events {
            if let existing = existingEvents[event.id] {
                refresh(existing, from: event)
                result.refreshedRecordCount += 1
            } else {
                context.insert(event)
                result.eventCount += 1
            }
        }

        let existingSleepSessions = Dictionary(
            try context.fetch(FetchDescriptor<SleepSession>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for session in sleepSessions {
            if let existing = existingSleepSessions[session.id] {
                refresh(existing, from: session)
                result.refreshedRecordCount += 1
            } else {
                context.insert(session)
                result.sleepSessionCount += 1
            }
        }

        let existingAwaySessions = Dictionary(
            try context.fetch(FetchDescriptor<AwaySession>()).map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        for session in awaySessions {
            if let existing = existingAwaySessions[session.id] {
                refresh(existing, from: session)
                result.refreshedRecordCount += 1
            } else {
                context.insert(session)
                result.awaySessionCount += 1
            }
        }

        let existingEmotions = try context.fetch(FetchDescriptor<EmotionLog>())
        for emotion in existingEmotions where retiredEmotionIDs.contains(emotion.id) {
            context.delete(emotion)
            result.removedRecordCount += 1
        }

        for event in existingEvents.values where retiredEventIDs.contains(event.id) {
            context.delete(event)
            result.removedRecordCount += 1
        }

        for goal in existingGoals.values where retiredGoalIDs.contains(goal.id) {
            context.delete(goal)
            result.removedRecordCount += 1
        }

        if result.totalChangedCount > 0 {
            try context.save()
        }
        return result
    }
}

private extension RoutinaScreenshotDataSeeder {
    struct SeedDates {
        var calendar: Calendar
        var today: Date

        init(referenceDate: Date, calendar: Calendar) {
            self.calendar = calendar
            self.today = calendar.startOfDay(for: referenceDate)
        }

        func at(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: day
            ) ?? day
        }
    }

    static func seedID(_ value: Int) -> UUID {
        let suffix = String(format: "%012X", value)
        return UUID(uuidString: "A11CE000-5EED-4000-8000-\(suffix)")!
    }

    @MainActor
    static func refresh(_ existing: RoutineTask, from template: RoutineTask) {
        CloudSharingService.SharedTaskPayload(task: template).apply(to: existing)
        existing.customTaskSectionID = template.customTaskSectionID
        existing.completedChecklistItemIDsStorage = template.completedChecklistItemIDsStorage
        existing.completedChecklistProgressStartedAt = template.completedChecklistProgressStartedAt
        existing.manualSectionOrderStorage = template.manualSectionOrderStorage
        existing.taskChoiceTieBreakScore = template.taskChoiceTieBreakScore
        existing.taskChoiceComparisonCount = template.taskChoiceComparisonCount
        existing.showsTaskDetailHeatmap = template.showsTaskDetailHeatmap
        existing.showsTaskDetailHistory = template.showsTaskDetailHistory
        existing.isTaskDetailCalendarExpanded = template.isTaskDetailCalendarExpanded
        existing.changeLogStorage = template.changeLogStorage
    }

    static func refresh(_ existing: RoutineGoal, from template: RoutineGoal) {
        existing.title = template.title
        existing.emoji = template.emoji
        existing.notes = template.notes
        existing.targetDate = template.targetDate
        existing.tags = template.tags
        existing.status = template.status
        existing.color = template.color
        existing.parentGoalID = template.parentGoalID
        existing.rejectedTaskSuggestionIDs = template.rejectedTaskSuggestionIDs
        existing.createdAt = template.createdAt
        existing.sortOrder = template.sortOrder
    }

    static func refresh(_ existing: RoutineLog, from template: RoutineLog) {
        existing.timestamp = template.timestamp
        existing.scheduledOccurrenceAt = template.scheduledOccurrenceAt
        existing.taskID = template.taskID
        existing.kind = template.kind
        existing.actualDurationMinutes = template.actualDurationMinutes
        existing.hasSpecificWorkTime = template.hasSpecificWorkTime
        existing.sourceTaskID = template.sourceTaskID
        existing.isConfirmedAssumedDone = template.isConfirmedAssumedDone
    }

    static func refresh(_ existing: FocusSession, from template: FocusSession) {
        existing.taskID = template.taskID
        existing.startedAt = template.startedAt
        existing.plannedDurationSeconds = template.plannedDurationSeconds
        existing.completedAt = template.completedAt
        existing.abandonedAt = template.abandonedAt
        existing.pausedAt = template.pausedAt
        existing.accumulatedPausedSeconds = template.accumulatedPausedSeconds
        existing.tagName = template.tagName
    }

    static func refresh(_ existing: RoutineNote, from template: RoutineNote) {
        existing.title = template.title
        existing.body = template.body
        existing.tags = template.tags
        existing.imageData = template.imageData
        existing.voiceNoteData = template.voiceNoteData
        existing.voiceNoteDurationSeconds = template.voiceNoteDurationSeconds
        existing.voiceNoteCreatedAt = template.voiceNoteCreatedAt
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    static func refresh(_ existing: RoutineEvent, from template: RoutineEvent) {
        existing.title = template.title
        existing.notes = template.notes
        existing.emoji = template.emoji
        existing.tags = template.tags
        existing.isAllDay = template.isAllDay
        existing.startedAt = template.startedAt
        existing.endedAt = template.endedAt
        existing.reminderAt = template.reminderAt
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    static func refresh(_ existing: SleepSession, from template: SleepSession) {
        existing.startedAt = template.startedAt
        existing.endedAt = template.endedAt
        existing.targetDurationMinutes = template.targetDurationMinutes
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    static func refresh(_ existing: AwaySession, from template: AwaySession) {
        existing.presetRawValue = template.presetRawValue
        existing.title = template.title
        existing.linkedTaskID = template.linkedTaskID
        existing.startedAt = template.startedAt
        existing.plannedDurationSeconds = template.plannedDurationSeconds
        existing.completedAt = template.completedAt
        existing.endedEarlyAt = template.endedEarlyAt
        existing.extensionCount = template.extensionCount
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    static func makeCustomSections(dates: SeedDates) -> [HomeCustomTaskSection] {
        let launchID = seedID(20_000)
        let laterID = seedID(20_003)
        return [
            HomeCustomTaskSection(
                id: launchID,
                surface: .radar,
                title: "Launch",
                createdAt: dates.at(dayOffset: -60, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Routina", "Work"]),
                colorHex: "#5856D6"
            ),
            HomeCustomTaskSection(
                id: seedID(20_001),
                parentSectionID: launchID,
                surface: .radar,
                title: "App Store",
                createdAt: dates.at(dayOffset: -45, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Release"]),
                colorHex: "#AF52DE"
            ),
            HomeCustomTaskSection(
                id: seedID(20_002),
                surface: .radar,
                title: "Personal",
                createdAt: dates.at(dayOffset: -55, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Personal", "Health"]),
                colorHex: "#34C759"
            ),
            HomeCustomTaskSection(
                id: laterID,
                surface: .backlog,
                title: "Later",
                createdAt: dates.at(dayOffset: -42, hour: 9),
                colorHex: "#FF9F0A"
            ),
            HomeCustomTaskSection(
                id: seedID(20_004),
                parentSectionID: laterID,
                surface: .backlog,
                title: "Research",
                createdAt: dates.at(dayOffset: -36, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Research"]),
                colorHex: "#64D2FF"
            )
        ]
    }

    static func makeTasks(
        dates: SeedDates,
        customSections: [HomeCustomTaskSection]
    ) -> [RoutineTask] {
        let launchSectionID = customSections[0].id
        let appStoreSectionID = customSections[1].id
        let personalSectionID = customSections[2].id
        let laterSectionID = customSections[3].id
        let researchSectionID = customSections[4].id
        let releaseSubmissionID = seedID(11)
        let verifyBackupID = seedID(12)
        let currentWeekday = dates.calendar.component(.weekday, from: dates.today)

        let tasks = [
            RoutineTask(
                id: seedID(1),
                name: "Morning stretch",
                emoji: "🧘",
                taskDescription: "A short scheduled routine that starts the day with movement.",
                notes: "A gentle ten-minute mobility reset before the day begins.",
                customTaskSectionID: personalSectionID,
                priority: .medium,
                importance: .level2,
                urgency: .level2,
                thinkingNeeded: .low,
                tags: ["Morning", "Health"],
                flags: [RoutineFlagRuleKind.autoAssumeDone.builtInFlagName],
                goalIDs: [],
                scheduleMode: .softInterval,
                interval: 1,
                recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 7, minute: 30)),
                lastDone: dates.at(dayOffset: 0, hour: 7, minute: 35),
                pinnedAt: dates.at(dayOffset: -30, hour: 8),
                color: .green,
                createdAt: dates.at(dayOffset: -45, hour: 8),
                autoAssumeDailyDone: true,
                autoAssumeDoneTimeOfDay: RoutineTimeOfDay(hour: 8, minute: 0),
                estimatedDurationMinutes: 10,
                showsTaskDetailHeatmap: true,
                showsTaskDetailHistory: true,
                isTaskDetailCalendarExpanded: true,
                hasExplicitImportance: true,
                hasExplicitUrgency: true
            ),
            RoutineTask(
                id: seedID(2),
                name: "Deep work session",
                emoji: "🧠",
                taskDescription: "Protect one uninterrupted block for the release's hardest creative work.",
                notes: "One quiet block for the most important creative work.",
                plannedDate: dates.at(dayOffset: 0, hour: 9, minute: 30),
                customTaskSectionID: launchSectionID,
                priority: .high,
                importance: .level4,
                urgency: .level3,
                pressure: .medium,
                pressureUpdatedAt: dates.at(dayOffset: -1, hour: 9),
                thinkingNeeded: .high,
                tags: ["Focus", "Creative"],
                goalIDs: [],
                scheduleMode: .fixedInterval,
                interval: 1,
                recurrenceRule: .interval(days: 1, at: RoutineTimeOfDay(hour: 9, minute: 30)),
                lastDone: dates.at(dayOffset: -1, hour: 11),
                pinnedAt: dates.at(dayOffset: -29, hour: 8),
                color: .blue,
                createdAt: dates.at(dayOffset: -42, hour: 9),
                estimatedDurationMinutes: 90,
                actualDurationMinutes: 80,
                storyPoints: 5,
                focusModeEnabled: true,
                showsTaskDetailHeatmap: true,
                showsTaskDetailHistory: true,
                hasExplicitImportance: true,
                hasExplicitUrgency: true
            ),
            RoutineTask(
                id: seedID(3),
                name: "Walk outside",
                emoji: "🚶",
                taskDescription: "A flexible daylight break that stays visible without becoming overdue.",
                notes: "Leave the desk, get daylight, and let the mind reset.",
                customTaskSectionID: personalSectionID,
                priority: .low,
                importance: .level2,
                urgency: .level1,
                thinkingNeeded: .low,
                tags: ["Health", "Outside"],
                flags: [RoutineFlagRuleKind.hideFromCalendarList.builtInFlagName],
                goalIDs: [],
                scheduleMode: .softInterval,
                interval: 1,
                lastDone: dates.at(dayOffset: -1, hour: 16),
                color: .teal,
                createdAt: dates.at(dayOffset: -38, hour: 9),
                estimatedDurationMinutes: 30,
                showsTaskDetailHeatmap: true
            ),
            RoutineTask(
                id: seedID(4),
                name: "Read 20 pages",
                emoji: "📚",
                taskDescription: "A when-needed reading habit without a fixed recurrence.",
                notes: "Read slowly and capture one useful idea.",
                customTaskSectionID: personalSectionID,
                priority: .medium,
                importance: .level3,
                urgency: .level1,
                thinkingNeeded: .medium,
                tags: ["Learning", "Evening"],
                flags: [RoutineFlagRuleKind.hideFromTaskLadder.builtInFlagName],
                scheduleMode: .softInterval,
                interval: 2,
                color: .purple,
                createdAt: dates.at(dayOffset: -35, hour: 9),
                estimatedDurationMinutes: 25,
                cadenceEnabled: false,
                autoPauseAfterCompletion: true,
                nudgesEnabled: false,
                showsTaskDetailHistory: true
            ),
            RoutineTask(
                id: seedID(5),
                name: "Weekly review",
                emoji: "🗓️",
                taskDescription: "A scheduled review whose Task Ladder values rise as its due time approaches.",
                notes: "Review wins, open loops, and next week's three priorities.",
                customTaskSectionID: launchSectionID,
                priority: .high,
                importance: .level3,
                urgency: .level3,
                pressure: .low,
                temporalWeightRule: RoutineTaskTemporalWeightRule(
                    importance: RoutineTaskTemporalWeightPolicy(
                        target: .level4,
                        timing: .gradualBeforeDue,
                        days: 3
                    ),
                    urgency: RoutineTaskTemporalWeightPolicy(
                        target: .level4,
                        timing: .onDueDate
                    ),
                    pressure: RoutineTaskTemporalWeightPolicy(
                        target: .high,
                        timing: .gradualWhileOverdue,
                        days: 2
                    )
                ),
                taskLadderEntryWindow: .beforeDue(days: 3),
                thinkingNeeded: .high,
                tags: ["Planning", "Weekly"],
                goalIDs: [],
                steps: [
                    RoutineStep(title: "Review completed work"),
                    RoutineStep(title: "Clear open loops"),
                    RoutineStep(title: "Choose next priorities")
                ],
                scheduleMode: .fixedInterval,
                interval: 7,
                recurrenceRule: .weekly(
                    on: currentWeekday,
                    at: RoutineTimeOfDay(hour: 17, minute: 0)
                ),
                lastDone: dates.at(dayOffset: -8, hour: 17),
                color: .orange,
                createdAt: dates.at(dayOffset: -50, hour: 9),
                estimatedDurationMinutes: 45,
                showsTaskDetailHistory: true
            ),
            RoutineTask(
                id: seedID(6),
                name: "Grocery restock",
                emoji: "🛒",
                taskDescription: "A runout checklist where each item becomes due on its own rhythm.",
                notes: "Pick up only the items that are due for restocking.",
                customTaskSectionID: personalSectionID,
                priority: .medium,
                importance: .level2,
                urgency: .level3,
                thinkingNeeded: .low,
                tags: ["Home", "Errands"],
                checklistItems: [
                    RoutineChecklistItem(
                        id: seedID(61),
                        title: "Coffee",
                        intervalDays: 14,
                        lastPurchasedAt: dates.at(dayOffset: -15, hour: 18),
                        createdAt: dates.at(dayOffset: -40, hour: 10)
                    ),
                    RoutineChecklistItem(
                        id: seedID(62),
                        title: "Fresh fruit",
                        intervalDays: 5,
                        lastPurchasedAt: dates.at(dayOffset: -4, hour: 18),
                        createdAt: dates.at(dayOffset: -40, hour: 10)
                    ),
                    RoutineChecklistItem(
                        id: seedID(63),
                        title: "Oat milk",
                        intervalDays: 7,
                        lastPurchasedAt: dates.at(dayOffset: -8, hour: 18),
                        createdAt: dates.at(dayOffset: -40, hour: 10)
                    )
                ],
                scheduleMode: .derivedFromChecklist,
                interval: 1,
                lastDone: dates.at(dayOffset: -4, hour: 18),
                color: .yellow,
                createdAt: dates.at(dayOffset: -40, hour: 10),
                estimatedDurationMinutes: 35
            ),
            RoutineTask(
                id: seedID(7),
                name: "Prepare App Store screenshots",
                emoji: "🖼️",
                taskDescription: "Prepare the accurate product views used to introduce Routina on both platforms.",
                notes: "Capture clean Home, Planner, Backlog, Task Ladder, Task Details, Timeline, and Stats views.",
                links: ["https://developer.apple.com/app-store/product-page/"],
                deadline: dates.at(dayOffset: 0, hour: 18),
                plannedDate: dates.at(dayOffset: 0, hour: 14),
                customTaskSectionID: appStoreSectionID,
                priority: .urgent,
                importance: .level4,
                urgency: .level4,
                pressure: .medium,
                pressureUpdatedAt: dates.at(dayOffset: -1, hour: 10),
                thinkingNeeded: .high,
                tags: ["Routina", "Creative", "Release"],
                goalIDs: [],
                relationships: [
                    RoutineTaskRelationship(
                        targetTaskID: releaseSubmissionID,
                        kind: .blocks
                    )
                ],
                steps: [
                    RoutineStep(title: "Prepare realistic sample data"),
                    RoutineStep(title: "Capture iPhone release screens"),
                    RoutineStep(title: "Capture Mac release screens"),
                    RoutineStep(title: "Review every image at App Store size")
                ],
                scheduleMode: .oneOff,
                pinnedAt: dates.at(dayOffset: -2, hour: 9),
                color: .indigo,
                createdAt: dates.at(dayOffset: -6, hour: 10),
                todoStateRawValue: TodoState.inProgress.rawValue,
                estimatedDurationMinutes: 90,
                storyPoints: 5,
                focusModeEnabled: true,
                hasExplicitImportance: true,
                hasExplicitUrgency: true,
                comments: [
                    RoutineTaskComment(
                        id: seedID(71),
                        body: "Use one coherent dataset across both platforms.",
                        createdAt: dates.at(dayOffset: -1, hour: 16)
                    )
                ]
            ),
            RoutineTask(
                id: seedID(8),
                name: "Send project update",
                emoji: "✉️",
                taskDescription: "Summarize progress without burying the next concrete action.",
                notes: "Share progress, current risks, and the next milestone.",
                deadline: dates.at(dayOffset: 1, hour: 16),
                plannedDate: dates.at(dayOffset: 0, hour: 16),
                customTaskSectionID: launchSectionID,
                priority: .high,
                importance: .level3,
                urgency: .level3,
                tags: ["Work", "Communication"],
                goalIDs: [],
                scheduleMode: .oneOff,
                color: .blue,
                createdAt: dates.at(dayOffset: -4, hour: 11),
                todoStateRawValue: TodoState.ready.rawValue,
                estimatedDurationMinutes: 30,
                storyPoints: 2
            ),
            RoutineTask(
                id: seedID(9),
                name: "Book dentist appointment",
                emoji: "🦷",
                taskDescription: "A short personal task with a deadline and reminder.",
                notes: "Call the nearby clinic and choose a morning appointment.",
                deadline: dates.at(dayOffset: 5, hour: 17),
                customTaskSectionID: personalSectionID,
                reminderAt: dates.at(dayOffset: 3, hour: 10),
                priority: .medium,
                importance: .level3,
                urgency: .level2,
                tags: ["Personal", "Health"],
                scheduleMode: .oneOff,
                color: .pink,
                createdAt: dates.at(dayOffset: -3, hour: 12),
                todoStateRawValue: TodoState.ready.rawValue,
                estimatedDurationMinutes: 15,
                storyPoints: 1
            ),
            RoutineTask(
                id: seedID(10),
                name: "Renew design software",
                emoji: "💳",
                taskDescription: "Resolve an overdue renewal before it interrupts release work.",
                notes: "Compare annual pricing before the trial ends.",
                deadline: dates.at(dayOffset: -1, hour: 17),
                customTaskSectionID: launchSectionID,
                priority: .high,
                importance: .level3,
                urgency: .level4,
                pressure: .high,
                pressureUpdatedAt: dates.at(dayOffset: -2, hour: 9),
                tags: ["Admin", "Routina"],
                goalIDs: [],
                scheduleMode: .oneOff,
                color: .red,
                createdAt: dates.at(dayOffset: -7, hour: 9),
                todoStateRawValue: TodoState.blocked.rawValue,
                estimatedDurationMinutes: 20,
                storyPoints: 1
            ),
            RoutineTask(
                id: releaseSubmissionID,
                name: "Submit the release candidate",
                emoji: "🚀",
                taskDescription: "The final submission remains blocked until its release evidence is ready.",
                notes: "Upload both platforms only after screenshots and backup verification are complete.",
                deadline: dates.at(dayOffset: 2, hour: 16),
                customTaskSectionID: appStoreSectionID,
                priority: .urgent,
                importance: .level4,
                urgency: .level4,
                pressure: .high,
                pressureUpdatedAt: dates.at(dayOffset: -1, hour: 11),
                thinkingNeeded: .high,
                tags: ["Routina", "Release"],
                goalIDs: [],
                relationships: [
                    RoutineTaskRelationship(targetTaskID: seedID(7), kind: .blockedBy),
                    RoutineTaskRelationship(targetTaskID: verifyBackupID, kind: .blockedBy)
                ],
                scheduleMode: .oneOff,
                color: .red,
                createdAt: dates.at(dayOffset: -5, hour: 9),
                todoStateRawValue: TodoState.blocked.rawValue,
                estimatedDurationMinutes: 60,
                storyPoints: 3,
                hasExplicitImportance: true,
                hasExplicitUrgency: true
            ),
            RoutineTask(
                id: verifyBackupID,
                name: "Verify the release backup",
                emoji: "🛟",
                taskDescription: "Audit a portable backup before treating it as a recovery path.",
                notes: "Check the receipt, attachments, isolated restore, and semantic round trip.",
                deadline: dates.at(dayOffset: 0, hour: 15),
                plannedDate: dates.at(dayOffset: 0, hour: 13),
                customTaskSectionID: appStoreSectionID,
                priority: .high,
                importance: .level4,
                urgency: .level3,
                pressure: .medium,
                pressureUpdatedAt: dates.at(dayOffset: -1, hour: 12),
                thinkingNeeded: .high,
                tags: ["Routina", "Release", "Backup"],
                goalIDs: [],
                relationships: [
                    RoutineTaskRelationship(targetTaskID: releaseSubmissionID, kind: .blocks)
                ],
                steps: [
                    RoutineStep(title: "Export verified package"),
                    RoutineStep(title: "Run isolated restore audit"),
                    RoutineStep(title: "Confirm recovery receipt")
                ],
                scheduleMode: .oneOff,
                color: .teal,
                createdAt: dates.at(dayOffset: -4, hour: 9),
                todoStateRawValue: TodoState.inProgress.rawValue,
                estimatedDurationMinutes: 40,
                storyPoints: 3
            ),
            RoutineTask(
                id: seedID(13),
                name: "Plan an autumn weekend",
                emoji: "🍂",
                taskDescription: "A later idea with a broad availability window instead of a false deadline.",
                notes: "Choose a quiet destination once the release is finished.",
                customTaskSectionID: laterSectionID,
                availabilityStartDate: dates.at(dayOffset: 30, hour: 0),
                availabilityEndDate: dates.at(dayOffset: 45, hour: 23, minute: 59),
                priority: .low,
                importance: .level2,
                urgency: .level1,
                thinkingNeeded: .medium,
                tags: ["Personal", "Travel"],
                scheduleMode: .oneOff,
                color: .orange,
                createdAt: dates.at(dayOffset: -10, hour: 17),
                todoStateRawValue: TodoState.ready.rawValue,
                estimatedDurationMinutes: 30
            ),
            RoutineTask(
                id: seedID(14),
                name: "Compare ergonomic standing desks for a calmer workspace",
                emoji: "🪑",
                taskDescription: "Research kept out of the daily list until it is deliberately promoted.",
                notes: "Compare stability, usable depth, warranty, and delivery instead of price alone.",
                customTaskSectionID: researchSectionID,
                priority: .low,
                importance: .level2,
                urgency: .level1,
                thinkingNeeded: .high,
                tags: ["Research", "Workspace"],
                scheduleMode: .oneOff,
                color: .blue,
                createdAt: dates.at(dayOffset: -9, hour: 14),
                todoStateRawValue: TodoState.ready.rawValue,
                estimatedDurationMinutes: 45,
                storyPoints: 2
            ),
            RoutineTask(
                id: seedID(15),
                name: "Call family",
                emoji: "☎️",
                taskDescription: "A gentle weekly rhythm measured from the last completed call.",
                notes: "Make time for an unhurried conversation.",
                customTaskSectionID: personalSectionID,
                priority: .medium,
                importance: .level4,
                urgency: .level2,
                thinkingNeeded: .low,
                tags: ["Personal", "Family"],
                scheduleMode: .softInterval,
                interval: 7,
                recurrenceRule: .interval(
                    days: 7,
                    at: RoutineTimeOfDay(hour: 19, minute: 0)
                ),
                lastDone: dates.at(dayOffset: -6, hour: 19),
                color: .pink,
                createdAt: dates.at(dayOffset: -50, hour: 12),
                estimatedDurationMinutes: 30,
                showsTaskDetailHistory: true
            ),
            RoutineTask(
                id: seedID(16),
                name: "Meet a friend at Brandenburg Gate",
                emoji: "☕️",
                taskDescription: "A one-time plan with a real destination and a visible reminder.",
                notes: "Meet by the east side before walking to a nearby café.",
                deadline: dates.at(dayOffset: 2, hour: 20),
                plannedDate: dates.at(dayOffset: 2, hour: 18),
                customTaskSectionID: personalSectionID,
                reminderAt: dates.at(dayOffset: 2, hour: 16),
                importance: .level3,
                urgency: .level2,
                thinkingNeeded: .low,
                destinationAddress: "Brandenburg Gate, Pariser Platz, 10117 Berlin",
                destinationLatitude: 52.5162746,
                destinationLongitude: 13.3777041,
                tags: ["Personal", "Friends"],
                scheduleMode: .oneOff,
                color: .teal,
                createdAt: dates.at(dayOffset: -2, hour: 12),
                todoStateRawValue: TodoState.ready.rawValue,
                estimatedDurationMinutes: 90
            )
        ]

        tasks[6].linkItems = [
            RoutineTaskLink(
                title: "App Store product-page guidance",
                url: "https://developer.apple.com/app-store/product-page/"
            )
        ]
        return tasks
    }

    static func makeLogs(dates: SeedDates, tasks: [RoutineTask]) -> [RoutineLog] {
        var logs: [RoutineLog] = []
        var nextID = 1_000

        func append(
            taskIndex: Int,
            dayOffset: Int,
            hour: Int,
            minute: Int = 0,
            kind: RoutineLogKind = .completed,
            duration: Int? = nil
        ) {
            logs.append(
                RoutineLog(
                    id: seedID(nextID),
                    timestamp: dates.at(dayOffset: dayOffset, hour: hour, minute: minute),
                    taskID: tasks[taskIndex].id,
                    kind: kind,
                    actualDurationMinutes: duration,
                    hasSpecificWorkTime: duration == nil ? nil : true
                )
            )
            nextID += 1
        }

        for dayOffset in -28...0 {
            if dayOffset == 0 || !dayOffset.isMultiple(of: 7) {
                append(
                    taskIndex: 0,
                    dayOffset: dayOffset,
                    hour: 7,
                    minute: 35,
                    duration: 10
                )
            } else {
                append(taskIndex: 0, dayOffset: dayOffset, hour: 20, kind: .missed)
            }

            if dayOffset < 0, !dayOffset.isMultiple(of: 3) {
                append(
                    taskIndex: 1,
                    dayOffset: dayOffset,
                    hour: 10,
                    minute: 45,
                    duration: 75 + abs(dayOffset % 3) * 10
                )
            }

            if dayOffset < 0, dayOffset.isMultiple(of: 2) {
                append(
                    taskIndex: 2,
                    dayOffset: dayOffset,
                    hour: 16,
                    duration: 30
                )
            }

            if dayOffset <= -2, dayOffset.isMultiple(of: 2) {
                append(
                    taskIndex: 3,
                    dayOffset: dayOffset,
                    hour: 21,
                    duration: 25
                )
            }
        }

        for dayOffset in [-22, -15, -8] {
            append(taskIndex: 4, dayOffset: dayOffset, hour: 17, duration: 45)
        }

        for dayOffset in [-18, -11, -4] {
            append(taskIndex: 5, dayOffset: dayOffset, hour: 18, duration: 35)
        }

        append(taskIndex: 7, dayOffset: -3, hour: 15, kind: .canceled)
        return logs
    }

    static func makePlannerBlocks(
        dates: SeedDates,
        tasks: [RoutineTask]
    ) -> [DayPlanBlockRecord] {
        let dayKey = DayPlanStorage.dayKey(for: dates.today, calendar: dates.calendar)
        let specifications: [(Int, Int, Int)] = [
            (0, 7 * 60 + 30, 30),
            (1, 9 * 60 + 30, 90),
            (7, 13 * 60, 30),
            (6, 14 * 60, 90),
            (2, 17 * 60 + 15, 30)
        ]

        return specifications.enumerated().map { index, specification in
            let task = tasks[specification.0]
            return DayPlanBlockRecord(
                id: seedID(3_000 + index),
                taskID: task.id,
                dayKey: dayKey,
                startMinute: specification.1,
                durationMinutes: specification.2,
                titleSnapshot: task.name ?? "Untitled task",
                emojiSnapshot: task.emoji,
                createdAt: dates.at(dayOffset: -1, hour: 18),
                updatedAt: dates.at(dayOffset: -1, hour: 18)
            )
        }
    }

    static func makeFocusSessions(
        dates: SeedDates,
        tasks: [RoutineTask]
    ) -> [FocusSession] {
        (0..<14).map { index in
            let dayOffset = -(index + 1)
            let startedAt = dates.at(
                dayOffset: dayOffset,
                hour: index.isMultiple(of: 3) ? 14 : 9,
                minute: 30
            )
            let durationMinutes = 45 + (index % 4) * 15
            return FocusSession(
                id: seedID(4_000 + index),
                taskID: index.isMultiple(of: 4) ? tasks[6].id : tasks[1].id,
                startedAt: startedAt,
                plannedDurationSeconds: TimeInterval(durationMinutes * 60),
                completedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        }
    }

    static func makeNotes(dates: SeedDates) -> [RoutineNote] {
        [
            RoutineNote(
                id: seedID(7_000),
                title: "Screenshot direction",
                body: "Keep the interface calm and spacious. Show enough real activity to make every screen feel lived in.",
                tags: ["Routina", "Creative"],
                createdAt: dates.at(dayOffset: -2, hour: 11),
                updatedAt: dates.at(dayOffset: -1, hour: 15)
            ),
            RoutineNote(
                id: seedID(7_001),
                title: "Weekly reflection",
                body: "The best work happened after protecting the first ninety minutes of the morning.",
                tags: ["Reflection", "Focus"],
                createdAt: dates.at(dayOffset: -6, hour: 18),
                updatedAt: dates.at(dayOffset: -6, hour: 18)
            ),
            RoutineNote(
                id: seedID(7_002),
                body: "Finished the core flow. Next: polish the visuals and prepare the release notes.",
                tags: ["Status", "Routina"],
                createdAt: dates.at(dayOffset: -1, hour: 17),
                updatedAt: dates.at(dayOffset: -1, hour: 17)
            )
        ]
    }

    static func makeSleepSessions(dates: SeedDates) -> [SleepSession] {
        (0..<10).map { index in
            let startedAt = dates.at(dayOffset: -(index + 1), hour: 23)
            let durationMinutes = 7 * 60 + 15 + (index % 4) * 15
            return SleepSession(
                id: seedID(5_000 + index),
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                targetDurationMinutes: 8 * 60,
                createdAt: startedAt,
                updatedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        }
    }

    static func makeAwaySessions(
        dates: SeedDates,
        tasks: [RoutineTask]
    ) -> [AwaySession] {
        [
            (6_000, -1, 12, AwaySessionPreset.meal, "Lunch break", 35),
            (6_001, -2, 16, AwaySessionPreset.outside, "Afternoon walk", 30),
            (6_002, -4, 11, AwaySessionPreset.reset, "Screen break", 15),
            (6_003, -6, 18, AwaySessionPreset.windDown, "Evening reset", 30)
        ].map { id, dayOffset, hour, preset, title, durationMinutes in
            let startedAt = dates.at(dayOffset: dayOffset, hour: hour)
            return AwaySession(
                id: seedID(id),
                preset: preset,
                title: title,
                linkedTaskID: preset == .outside ? tasks[2].id : nil,
                startedAt: startedAt,
                plannedDurationSeconds: TimeInterval(durationMinutes * 60),
                completedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                createdAt: startedAt,
                updatedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        }
    }

}
