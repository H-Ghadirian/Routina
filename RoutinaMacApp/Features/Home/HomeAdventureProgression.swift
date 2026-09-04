import Foundation

enum HomeAdventureProgressionBuilder {
    struct Input {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var focusSessions: [FocusSession] = []
        var sprintFocusSessions: [SprintFocusSessionRecord] = []
        var sleepSessions: [SleepSession] = []
        var awaySessions: [AwaySession] = []
        var dayPlanBlocks: [DayPlanBlockRecord] = []
        var emotionLogs: [EmotionLog] = []
        var notes: [RoutineNote] = []
        var events: [RoutineEvent] = []
        var goals: [RoutineGoal] = []
        var placeCheckInSessions: [PlaceCheckInSession] = []
        let referenceDate: Date
        let calendar: Calendar
    }

    static func build(_ input: Input) -> HomeAdventureProgression {
        let metrics = Metrics(input)
        let sources = coinSources(from: metrics)
        let totalCoins = sources.reduce(0) { $0 + $1.coins }
        let totalXP =
            metrics.completedLogCount * 10
            + metrics.createdTaskCount * 4
            + metrics.taskFocusBlockCount * 3
            + metrics.boardFocusBlockCount * 4
            + metrics.plannerBlockCount * 3
            + metrics.plannedHourCount
            + metrics.plannerRefinementCount * 2
            + metrics.completedSleepCount * 18
            + metrics.completedAwayCount * 10
            + metrics.captureActionCount * 5
            + metrics.goalCount * 12
            + metrics.placeCheckInCount * 8
        let levelXP = HomeAdventureProgression.xpPerRank
        let level = max(1, totalXP / levelXP + 1)
        let currentLevelXP = max(0, totalXP - ((level - 1) * levelXP))
        let levelProgress = min(max(Double(currentLevelXP) / Double(levelXP), 0), 1)
        let actionCount = metrics.rewardedActionCount
        let activeDayCount = metrics.activeDayCount
        let worlds = HomeAdventureContentCatalog.shared.worlds.map { template in
            HomeAdventureWorld(
                id: template.id,
                title: template.title,
                subtitle: template.subtitle,
                systemImage: template.systemImage,
                accentName: template.accentName,
                artAssetName: template.artAssetName,
                requiredCoins: template.requiredCoins,
                requiredActions: template.requiredActions,
                stages: template.stages.map { stage in
                    resolvedStage(
                        stage,
                        totalCoins: totalCoins,
                        actionCount: actionCount,
                        activeDayCount: activeDayCount
                    )
                }
            )
        }
        let allStages = worlds.flatMap(\.stages)
        let completedStageCount = allStages.filter { $0.status == .cleared }.count
        let nextLockedStage = allStages.first { $0.status == .locked }
        let items = HomeAdventureContentCatalog.shared.items.map { item in
            HomeAdventureItem(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                systemImage: item.systemImage,
                kind: item.kind,
                requiredCoins: item.requiredCoins,
                requiredStageCount: item.requiredStageCount,
                isUnlocked: totalCoins >= item.requiredCoins && completedStageCount >= item.requiredStageCount
            )
        }

        return HomeAdventureProgression(
            totalCoins: totalCoins,
            totalXP: totalXP,
            level: level,
            levelProgress: levelProgress,
            activeDayCount: activeDayCount,
            actionCount: actionCount,
            completedStageCount: completedStageCount,
            unlockedWorldCount: worlds.filter(\.isUnlocked).count,
            unlockedItemCount: items.filter(\.isUnlocked).count,
            nextLockedStage: nextLockedStage,
            worlds: worlds,
            items: items,
            sources: sources
        )
    }

    private static func resolvedStage(
        _ stage: StageTemplate,
        totalCoins: Int,
        actionCount: Int,
        activeDayCount: Int
    ) -> HomeAdventureStage {
        let coinStarEarned = totalCoins >= stage.requiredCoins
        let actionStarEarned = actionCount >= stage.requiredActions
        let activeDayStarEarned = activeDayCount >= stage.requiredActiveDays
        let status: HomeAdventureStage.Status
        if !coinStarEarned {
            status = .locked
        } else if coinStarEarned && actionStarEarned && activeDayStarEarned {
            status = .cleared
        } else {
            status = .available
        }

        return HomeAdventureStage(
            id: stage.id,
            worldID: stage.worldID,
            number: stage.number,
            title: stage.title,
            subtitle: stage.subtitle,
            requiredCoins: stage.requiredCoins,
            requiredActions: stage.requiredActions,
            requiredActiveDays: stage.requiredActiveDays,
            rewardCoins: stage.rewardCoins,
            coinStarEarned: coinStarEarned,
            actionStarEarned: actionStarEarned,
            activeDayStarEarned: activeDayStarEarned,
            status: status
        )
    }

    private static func coinSources(from metrics: Metrics) -> [HomeAdventureCoinSource] {
        let countsByRuleID: [String: Int] = [
            "done": metrics.completedLogCount,
            "created": metrics.createdTaskCount,
            "focus": metrics.taskFocusBlockCount,
            "boardFocus": metrics.boardFocusBlockCount,
            "plannerBlocks": metrics.plannerBlockCount,
            "plannedHours": metrics.plannedHourCount,
            "plannerRefinements": metrics.plannerRefinementCount,
            "sleep": metrics.completedSleepCount,
            "away": metrics.completedAwayCount,
            "captures": metrics.captureActionCount,
            "goals": metrics.goalCount,
            "places": metrics.placeCheckInCount,
        ]

        let sources = HomeAdventureCoinRule.all.map { rule in
            rule.source(count: countsByRuleID[rule.id] ?? 0)
        }

        return sources.filter { $0.count > .zero || $0.coins > 0 }
    }
}

private struct Metrics {
    let completedLogCount: Int
    let createdTaskCount: Int
    let taskFocusBlockCount: Int
    let boardFocusBlockCount: Int
    let plannerBlockCount: Int
    let plannedHourCount: Int
    let plannerRefinementCount: Int
    let completedSleepCount: Int
    let completedAwayCount: Int
    let captureActionCount: Int
    let goalCount: Int
    let placeCheckInCount: Int
    let activeDayCount: Int

    var rewardedActionCount: Int {
        completedLogCount
            + createdTaskCount
            + taskFocusBlockCount
            + boardFocusBlockCount
            + plannerBlockCount
            + plannedHourCount
            + plannerRefinementCount
            + completedSleepCount
            + completedAwayCount
            + captureActionCount
            + goalCount
            + placeCheckInCount
    }

    init(_ input: HomeAdventureProgressionBuilder.Input) {
        completedLogCount = input.logs.filter { $0.kind == .completed }.count
        createdTaskCount = input.tasks.filter { $0.createdAt != nil }.count
        let taskFocusSeconds = input.focusSessions.reduce(0) { total, session in
            total + session.activeDurationSeconds(at: input.referenceDate)
        }
        let boardFocusSeconds = input.sprintFocusSessions.reduce(0) { total, session in
            total + session.activeDurationSeconds(at: input.referenceDate)
        }
        taskFocusBlockCount = FocusBlockProgress.filledBlockCount(for: taskFocusSeconds)
        boardFocusBlockCount = FocusBlockProgress.filledBlockCount(for: boardFocusSeconds)
        plannerBlockCount = input.dayPlanBlocks.count
        let plannedMinutes = input.dayPlanBlocks.reduce(0) { total, block in
            total + max(0, block.durationMinutes)
        }
        plannedHourCount = plannedMinutes / 60
        plannerRefinementCount =
            input.dayPlanBlocks.filter { block in
                block.updatedAt.timeIntervalSince(block.createdAt) > 1
            }.count
        completedSleepCount = input.sleepSessions.filter { !$0.isActive }.count
        completedAwayCount = input.awaySessions.filter { $0.state == .completed }.count
        captureActionCount = input.emotionLogs.count + input.notes.count + input.events.count
        goalCount = input.goals.count
        placeCheckInCount = input.placeCheckInSessions.count

        var activeDays = Set<Date>()
        func insertDay(_ date: Date?) {
            guard let date else { return }
            activeDays.insert(input.calendar.startOfDay(for: date))
        }
        input.logs.forEach { insertDay($0.timestamp) }
        input.tasks.forEach { insertDay($0.createdAt) }
        input.focusSessions.forEach { insertDay($0.startedAt) }
        input.sprintFocusSessions.forEach { insertDay($0.startedAt) }
        input.dayPlanBlocks.forEach { block in
            insertDay(block.createdAt)
            if block.updatedAt.timeIntervalSince(block.createdAt) > 1 {
                insertDay(block.updatedAt)
            }
        }
        input.sleepSessions.forEach { insertDay($0.startedAt) }
        input.awaySessions.forEach { insertDay($0.startedAt) }
        input.emotionLogs.forEach { insertDay($0.createdAt) }
        input.notes.forEach { insertDay($0.createdAt) }
        input.events.forEach { insertDay($0.startedAt ?? $0.createdAt) }
        input.goals.forEach { insertDay($0.createdAt) }
        input.placeCheckInSessions.forEach { insertDay($0.startedAt ?? $0.createdAt) }
        activeDayCount = activeDays.count
    }
}
