import Foundation

extension RoutinaScreenshotDataSeeder {
    static func makeMorningStretchTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(1),
            name: "Morning stretch",
            emoji: "🧘",
            taskDescription: "A short scheduled routine that starts the day with movement.",
            notes: "A gentle ten-minute mobility reset before the day begins.",
            customTaskSectionID: context.personalSectionID,
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
            lastDone: context.dates.at(dayOffset: 0, hour: 7, minute: 35),
            pinnedAt: context.dates.at(dayOffset: -30, hour: 8),
            color: .green,
            createdAt: context.dates.at(dayOffset: -45, hour: 8),
            autoAssumeDailyDone: true,
            autoAssumeDoneTimeOfDay: RoutineTimeOfDay(hour: 8, minute: 0),
            estimatedDurationMinutes: 10,
            showsTaskDetailHeatmap: true,
            showsTaskDetailHistory: true,
            isTaskDetailCalendarExpanded: true,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
    }

    static func makeDeepWorkSessionTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(2),
            name: "Deep work session",
            emoji: "🧠",
            taskDescription: "Protect one uninterrupted block for the release's hardest creative work.",
            notes: "One quiet block for the most important creative work.",
            plannedDate: context.dates.at(dayOffset: 0, hour: 9, minute: 30),
            customTaskSectionID: context.launchSectionID,
            priority: .high,
            importance: .level4,
            urgency: .level3,
            pressure: .medium,
            pressureUpdatedAt: context.dates.at(dayOffset: -1, hour: 9),
            thinkingNeeded: .high,
            tags: ["Focus", "Creative"],
            goalIDs: [],
            scheduleMode: .fixedInterval,
            interval: 1,
            recurrenceRule: .interval(days: 1, at: RoutineTimeOfDay(hour: 9, minute: 30)),
            lastDone: context.dates.at(dayOffset: -1, hour: 11),
            pinnedAt: context.dates.at(dayOffset: -29, hour: 8),
            color: .blue,
            createdAt: context.dates.at(dayOffset: -42, hour: 9),
            estimatedDurationMinutes: 90,
            actualDurationMinutes: 80,
            storyPoints: 5,
            focusModeEnabled: true,
            showsTaskDetailHeatmap: true,
            showsTaskDetailHistory: true,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
    }

    static func makeWalkOutsideTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(3),
            name: "Walk outside",
            emoji: "🚶",
            taskDescription: "A flexible daylight break that stays visible without becoming overdue.",
            notes: "Leave the desk, get daylight, and let the mind reset.",
            customTaskSectionID: context.personalSectionID,
            priority: .low,
            importance: .level2,
            urgency: .level1,
            thinkingNeeded: .low,
            tags: ["Health", "Outside"],
            flags: [RoutineFlagRuleKind.hideFromCalendarList.builtInFlagName],
            goalIDs: [],
            scheduleMode: .softInterval,
            interval: 1,
            lastDone: context.dates.at(dayOffset: -1, hour: 16),
            color: .teal,
            createdAt: context.dates.at(dayOffset: -38, hour: 9),
            estimatedDurationMinutes: 30,
            showsTaskDetailHeatmap: true
        )
    }

    static func makeReadTwentyPagesTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(4),
            name: "Read 20 pages",
            emoji: "📚",
            taskDescription: "A when-needed reading habit without a fixed recurrence.",
            notes: "Read slowly and capture one useful idea.",
            customTaskSectionID: context.personalSectionID,
            priority: .medium,
            importance: .level3,
            urgency: .level1,
            thinkingNeeded: .medium,
            tags: ["Learning", "Evening"],
            flags: [RoutineFlagRuleKind.hideFromTaskLadder.builtInFlagName],
            scheduleMode: .softInterval,
            interval: 2,
            color: .purple,
            createdAt: context.dates.at(dayOffset: -35, hour: 9),
            estimatedDurationMinutes: 25,
            cadenceEnabled: false,
            autoPauseAfterCompletion: true,
            nudgesEnabled: false,
            showsTaskDetailHistory: true
        )
    }

    static func makeWeeklyReviewTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(5),
            name: "Weekly review",
            emoji: "🗓️",
            taskDescription: "A scheduled review whose Task Ladder values rise as its due time approaches.",
            notes: "Review wins, open loops, and next week's three priorities.",
            customTaskSectionID: context.launchSectionID,
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
                RoutineStep(title: "Choose next priorities"),
            ],
            scheduleMode: .fixedInterval,
            interval: 7,
            recurrenceRule: .weekly(
                on: context.currentWeekday,
                at: RoutineTimeOfDay(hour: 17, minute: 0)
            ),
            lastDone: context.dates.at(dayOffset: -8, hour: 17),
            color: .orange,
            createdAt: context.dates.at(dayOffset: -50, hour: 9),
            estimatedDurationMinutes: 45,
            showsTaskDetailHistory: true
        )
    }

    static func makeGroceryRestockTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(6),
            name: "Grocery restock",
            emoji: "🛒",
            taskDescription: "A runout checklist where each item becomes due on its own rhythm.",
            notes: "Pick up only the items that are due for restocking.",
            customTaskSectionID: context.personalSectionID,
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
                    lastPurchasedAt: context.dates.at(dayOffset: -15, hour: 18),
                    createdAt: context.dates.at(dayOffset: -40, hour: 10)
                ),
                RoutineChecklistItem(
                    id: seedID(62),
                    title: "Fresh fruit",
                    intervalDays: 5,
                    lastPurchasedAt: context.dates.at(dayOffset: -4, hour: 18),
                    createdAt: context.dates.at(dayOffset: -40, hour: 10)
                ),
                RoutineChecklistItem(
                    id: seedID(63),
                    title: "Oat milk",
                    intervalDays: 7,
                    lastPurchasedAt: context.dates.at(dayOffset: -8, hour: 18),
                    createdAt: context.dates.at(dayOffset: -40, hour: 10)
                ),
            ],
            scheduleMode: .derivedFromChecklist,
            interval: 1,
            lastDone: context.dates.at(dayOffset: -4, hour: 18),
            color: .yellow,
            createdAt: context.dates.at(dayOffset: -40, hour: 10),
            estimatedDurationMinutes: 35
        )
    }

}
