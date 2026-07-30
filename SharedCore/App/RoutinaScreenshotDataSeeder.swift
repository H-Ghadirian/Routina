import Foundation
import SwiftData

struct RoutinaScreenshotDataSeedResult: Equatable, Sendable {
    var taskCount = 0
    var logCount = 0
    var plannerBlockCount = 0
    var focusSessionCount = 0
    var goalCount = 0
    var noteCount = 0
    var eventCount = 0
    var emotionCount = 0
    var sleepSessionCount = 0
    var awaySessionCount = 0

    var totalInsertedCount: Int {
        taskCount
            + logCount
            + plannerBlockCount
            + focusSessionCount
            + goalCount
            + noteCount
            + eventCount
            + emotionCount
            + sleepSessionCount
            + awaySessionCount
    }
}

enum RoutinaScreenshotDataSeeder {
    static let taskCount = 10

    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard AppEnvironment.isScreenshotDataSeedRequested else { return }

        do {
            let result = try seed(in: context)
            NSLog(
                "Routina screenshot data seed finished with \(result.totalInsertedCount) new records."
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
        let goals = makeGoals(dates: dates)
        let tasks = makeTasks(dates: dates, goals: goals)
        let logs = makeLogs(dates: dates, tasks: tasks)
        let plannerBlocks = makePlannerBlocks(dates: dates, tasks: tasks)
        let focusSessions = makeFocusSessions(dates: dates, tasks: tasks)
        let notes = makeNotes(dates: dates)
        let events = makeEvents(dates: dates)
        let sleepSessions = makeSleepSessions(dates: dates)
        let awaySessions = makeAwaySessions(dates: dates, tasks: tasks)
        let emotions = makeEmotions(
            dates: dates,
            tasks: tasks,
            goals: goals,
            notes: notes,
            sleepSessions: sleepSessions
        )

        var result = RoutinaScreenshotDataSeedResult()

        let existingGoalIDs = Set(try context.fetch(FetchDescriptor<RoutineGoal>()).map(\.id))
        for goal in goals where !existingGoalIDs.contains(goal.id) {
            context.insert(goal)
            result.goalCount += 1
        }

        let existingTaskIDs = Set(try context.fetch(FetchDescriptor<RoutineTask>()).map(\.id))
        for task in tasks where !existingTaskIDs.contains(task.id) {
            context.insert(task)
            result.taskCount += 1
        }

        let existingLogIDs = Set(try context.fetch(FetchDescriptor<RoutineLog>()).map(\.id))
        for log in logs where !existingLogIDs.contains(log.id) {
            context.insert(log)
            result.logCount += 1
        }

        let existingPlannerBlockIDs = Set(
            try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).map(\.id)
        )
        for block in plannerBlocks where !existingPlannerBlockIDs.contains(block.id) {
            context.insert(block)
            result.plannerBlockCount += 1
        }

        let existingFocusSessionIDs = Set(
            try context.fetch(FetchDescriptor<FocusSession>()).map(\.id)
        )
        for session in focusSessions where !existingFocusSessionIDs.contains(session.id) {
            context.insert(session)
            result.focusSessionCount += 1
        }

        let existingNoteIDs = Set(try context.fetch(FetchDescriptor<RoutineNote>()).map(\.id))
        for note in notes where !existingNoteIDs.contains(note.id) {
            context.insert(note)
            result.noteCount += 1
        }

        let existingEventIDs = Set(try context.fetch(FetchDescriptor<RoutineEvent>()).map(\.id))
        for event in events where !existingEventIDs.contains(event.id) {
            context.insert(event)
            result.eventCount += 1
        }

        let existingSleepSessionIDs = Set(
            try context.fetch(FetchDescriptor<SleepSession>()).map(\.id)
        )
        for session in sleepSessions where !existingSleepSessionIDs.contains(session.id) {
            context.insert(session)
            result.sleepSessionCount += 1
        }

        let existingAwaySessionIDs = Set(
            try context.fetch(FetchDescriptor<AwaySession>()).map(\.id)
        )
        for session in awaySessions where !existingAwaySessionIDs.contains(session.id) {
            context.insert(session)
            result.awaySessionCount += 1
        }

        let existingEmotionIDs = Set(try context.fetch(FetchDescriptor<EmotionLog>()).map(\.id))
        for emotion in emotions where !existingEmotionIDs.contains(emotion.id) {
            context.insert(emotion)
            result.emotionCount += 1
        }

        if result.totalInsertedCount > 0 {
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

    static func makeGoals(dates: SeedDates) -> [RoutineGoal] {
        let wellbeingID = seedID(101)
        return [
            RoutineGoal(
                id: wellbeingID,
                title: "Build a calmer workday",
                emoji: "🌿",
                notes: "Create a steady rhythm for focus, movement, and recovery.",
                targetDate: dates.at(dayOffset: 45, hour: 18),
                tags: ["Wellbeing", "Focus"],
                color: .green,
                createdAt: dates.at(dayOffset: -40, hour: 9),
                sortOrder: 0
            ),
            RoutineGoal(
                id: seedID(102),
                title: "Ship the next Routina release",
                emoji: "🚀",
                notes: "Polish the experience, prepare visuals, and publish the release.",
                targetDate: dates.at(dayOffset: 21, hour: 17),
                tags: ["Routina", "Creative"],
                color: .indigo,
                createdAt: dates.at(dayOffset: -32, hour: 10),
                sortOrder: 1
            ),
            RoutineGoal(
                id: seedID(103),
                title: "Protect deep work time",
                emoji: "🧠",
                tags: ["Focus"],
                color: .blue,
                parentGoalID: wellbeingID,
                createdAt: dates.at(dayOffset: -28, hour: 10),
                sortOrder: 0
            )
        ]
    }

    static func makeTasks(dates: SeedDates, goals: [RoutineGoal]) -> [RoutineTask] {
        let wellbeingGoalID = goals[0].id
        let releaseGoalID = goals[1].id
        let deepWorkGoalID = goals[2].id

        return [
            RoutineTask(
                id: seedID(1),
                name: "Morning stretch",
                emoji: "🧘",
                notes: "A gentle ten-minute mobility reset before the day begins.",
                priority: .medium,
                importance: .level2,
                urgency: .level2,
                tags: ["Morning", "Health"],
                goalIDs: [wellbeingGoalID],
                scheduleMode: .softInterval,
                interval: 1,
                recurrenceRule: .interval(days: 1, at: RoutineTimeOfDay(hour: 7, minute: 30)),
                lastDone: dates.at(dayOffset: 0, hour: 7, minute: 35),
                pinnedAt: dates.at(dayOffset: -30, hour: 8),
                color: .green,
                createdAt: dates.at(dayOffset: -45, hour: 8),
                estimatedDurationMinutes: 10,
                showsTaskDetailHeatmap: true,
                showsTaskDetailHistory: true
            ),
            RoutineTask(
                id: seedID(2),
                name: "Deep work session",
                emoji: "🧠",
                notes: "One quiet block for the most important creative work.",
                plannedDate: dates.at(dayOffset: 0, hour: 9, minute: 30),
                priority: .high,
                importance: .level4,
                urgency: .level3,
                tags: ["Focus", "Creative"],
                goalIDs: [deepWorkGoalID, releaseGoalID],
                scheduleMode: .fixedInterval,
                interval: 1,
                recurrenceRule: .interval(days: 1, at: RoutineTimeOfDay(hour: 9, minute: 30)),
                lastDone: dates.at(dayOffset: -1, hour: 11),
                pinnedAt: dates.at(dayOffset: -29, hour: 8),
                color: .blue,
                createdAt: dates.at(dayOffset: -42, hour: 9),
                estimatedDurationMinutes: 90,
                storyPoints: 5,
                focusModeEnabled: true,
                showsTaskDetailHeatmap: true,
                showsTaskDetailHistory: true,
                showsTaskDetailPriority: true
            ),
            RoutineTask(
                id: seedID(3),
                name: "Walk outside",
                emoji: "🚶",
                notes: "Leave the desk, get daylight, and let the mind reset.",
                priority: .low,
                importance: .level2,
                urgency: .level1,
                tags: ["Health", "Outside"],
                goalIDs: [wellbeingGoalID],
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
                notes: "Read slowly and capture one useful idea.",
                priority: .medium,
                importance: .level3,
                urgency: .level1,
                tags: ["Learning", "Evening"],
                scheduleMode: .softInterval,
                interval: 2,
                lastDone: dates.at(dayOffset: -2, hour: 21),
                color: .purple,
                createdAt: dates.at(dayOffset: -35, hour: 9),
                estimatedDurationMinutes: 25,
                showsTaskDetailHistory: true
            ),
            RoutineTask(
                id: seedID(5),
                name: "Weekly review",
                emoji: "🗓️",
                notes: "Review wins, open loops, and next week's three priorities.",
                priority: .high,
                importance: .level3,
                urgency: .level3,
                tags: ["Planning", "Weekly"],
                goalIDs: [wellbeingGoalID, releaseGoalID],
                steps: [
                    RoutineStep(title: "Review completed work"),
                    RoutineStep(title: "Clear open loops"),
                    RoutineStep(title: "Choose next priorities")
                ],
                scheduleMode: .fixedInterval,
                interval: 7,
                lastDone: dates.at(dayOffset: -8, hour: 17),
                color: .orange,
                createdAt: dates.at(dayOffset: -50, hour: 9),
                estimatedDurationMinutes: 45,
                showsTaskDetailHistory: true,
                showsTaskDetailPriority: true
            ),
            RoutineTask(
                id: seedID(6),
                name: "Grocery restock",
                emoji: "🛒",
                notes: "Pick up only the items that are due for restocking.",
                priority: .medium,
                importance: .level2,
                urgency: .level3,
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
                name: "Prepare product screenshots",
                emoji: "🖼️",
                notes: "Capture clean Home, Planner, Timeline, and Stats views.",
                links: ["https://developer.apple.com/app-store/product-page/"],
                deadline: dates.at(dayOffset: 0, hour: 18),
                plannedDate: dates.at(dayOffset: 0, hour: 14),
                priority: .urgent,
                importance: .level4,
                urgency: .level4,
                pressure: .medium,
                pressureUpdatedAt: dates.at(dayOffset: -1, hour: 10),
                tags: ["Routina", "Creative"],
                goalIDs: [releaseGoalID],
                steps: [
                    RoutineStep(title: "Prepare realistic sample data"),
                    RoutineStep(title: "Capture main window"),
                    RoutineStep(title: "Capture planner and stats"),
                    RoutineStep(title: "Review at App Store size")
                ],
                scheduleMode: .oneOff,
                pinnedAt: dates.at(dayOffset: -2, hour: 9),
                color: .indigo,
                createdAt: dates.at(dayOffset: -6, hour: 10),
                todoStateRawValue: TodoState.inProgress.rawValue,
                estimatedDurationMinutes: 90,
                storyPoints: 5,
                focusModeEnabled: true,
                showsTaskDetailPriority: true,
                comments: [
                    RoutineTaskComment(
                        id: seedID(71),
                        body: "Use the light theme for the first set.",
                        createdAt: dates.at(dayOffset: -1, hour: 16)
                    )
                ]
            ),
            RoutineTask(
                id: seedID(8),
                name: "Send project update",
                emoji: "✉️",
                notes: "Share progress, current risks, and the next milestone.",
                deadline: dates.at(dayOffset: 1, hour: 16),
                plannedDate: dates.at(dayOffset: 0, hour: 16),
                priority: .high,
                importance: .level3,
                urgency: .level3,
                tags: ["Work", "Communication"],
                goalIDs: [releaseGoalID],
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
                notes: "Call the nearby clinic and choose a morning appointment.",
                deadline: dates.at(dayOffset: 5, hour: 17),
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
                notes: "Compare annual pricing before the trial ends.",
                deadline: dates.at(dayOffset: -1, hour: 17),
                priority: .high,
                importance: .level3,
                urgency: .level4,
                pressure: .high,
                pressureUpdatedAt: dates.at(dayOffset: -2, hour: 9),
                tags: ["Admin", "Routina"],
                goalIDs: [releaseGoalID],
                scheduleMode: .oneOff,
                color: .red,
                createdAt: dates.at(dayOffset: -7, hour: 9),
                todoStateRawValue: TodoState.blocked.rawValue,
                estimatedDurationMinutes: 20,
                storyPoints: 1,
                showsTaskDetailPriority: true
            )
        ]
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

    static func makeEvents(dates: SeedDates) -> [RoutineEvent] {
        [
            RoutineEvent(
                id: seedID(8_000),
                title: "Design review",
                notes: "Review final screens and App Store assets.",
                emoji: "🎨",
                tags: ["Routina", "Creative"],
                isAllDay: false,
                startedAt: dates.at(dayOffset: 0, hour: 11, minute: 30),
                endedAt: dates.at(dayOffset: 0, hour: 12, minute: 15),
                createdAt: dates.at(dayOffset: -4, hour: 10),
                updatedAt: dates.at(dayOffset: -2, hour: 9)
            ),
            RoutineEvent(
                id: seedID(8_001),
                title: "Release checkpoint",
                notes: "Confirm copy, screenshots, and build readiness.",
                emoji: "🚀",
                tags: ["Routina", "Planning"],
                isAllDay: false,
                startedAt: dates.at(dayOffset: 2, hour: 15),
                endedAt: dates.at(dayOffset: 2, hour: 16),
                createdAt: dates.at(dayOffset: -3, hour: 10),
                updatedAt: dates.at(dayOffset: -3, hour: 10)
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

    static func makeEmotions(
        dates: SeedDates,
        tasks: [RoutineTask],
        goals: [RoutineGoal],
        notes: [RoutineNote],
        sleepSessions: [SleepSession]
    ) -> [EmotionLog] {
        let families: [EmotionFamily] = [
            .calm, .joy, .surpriseCuriosity, .calm, .joy,
            .fear, .calm, .joy, .surpriseCuriosity, .calm
        ]
        return families.enumerated().map { index, family in
            let valence = family == .fear ? -0.35 : 0.35 + Double(index % 3) * 0.15
            let arousal = family == .calm ? -0.35 : 0.25
            return EmotionLog(
                id: seedID(9_000 + index),
                family: family,
                label: family.defaultLabel,
                valence: valence,
                arousal: arousal,
                intensity: 2 + (index % 3),
                bodyAreas: family == .calm ? [.shoulders, .energy] : [.chest, .energy],
                reflection: index == 5
                    ? "A little deadline pressure, but the plan feels manageable."
                    : "The day felt balanced after a focused start.",
                linkedNoteID: index == 1 ? notes[1].id : nil,
                linkedGoalID: index == 2 ? goals[0].id : nil,
                linkedTaskID: index.isMultiple(of: 3) ? tasks[1].id : nil,
                linkedSleepSessionID: index < sleepSessions.count ? sleepSessions[index].id : nil,
                createdAt: dates.at(dayOffset: -index, hour: 18),
                updatedAt: dates.at(dayOffset: -index, hour: 18)
            )
        }
    }
}
