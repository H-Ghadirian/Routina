import Foundation

struct HomeAdventureProgression: Equatable {
    static let xpPerRank = 500

    var totalCoins: Int
    var totalXP: Int
    var level: Int
    var levelProgress: Double
    var activeDayCount: Int
    var actionCount: Int
    var completedStageCount: Int
    var unlockedWorldCount: Int
    var unlockedItemCount: Int
    var nextLockedStage: HomeAdventureStage?
    var worlds: [HomeAdventureWorld]
    var items: [HomeAdventureItem]
    var sources: [HomeAdventureCoinSource]

    var currentWorld: HomeAdventureWorld? {
        worlds.last { $0.isUnlocked }
    }

    var currentStage: HomeAdventureStage? {
        worlds.flatMap(\.stages).first { $0.status == .available }
            ?? worlds.flatMap(\.stages).last { $0.status == .cleared }
    }

    var nextRank: Int {
        level + 1
    }

    var currentRankXP: Int {
        totalXP % Self.xpPerRank
    }

    static let empty = HomeAdventureProgression(
        totalCoins: 0,
        totalXP: 0,
        level: 1,
        levelProgress: 0,
        activeDayCount: 0,
        actionCount: 0,
        completedStageCount: 0,
        unlockedWorldCount: 0,
        unlockedItemCount: 0,
        nextLockedStage: nil,
        worlds: [],
        items: [],
        sources: []
    )
}

struct HomeAdventureWallet: Equatable {
    let totalCoins: Int
    let actionCount: Int
    let activeDayCount: Int
    let completedStageCount: Int
    let worlds: [HomeAdventureWorld]
    let items: [HomeAdventureItem]
    let ownedItemIDs: Set<String>
    let unlockedWorldIDs: Set<String>
    let unlockedStageIDs: Set<String>

    init(
        totalCoins: Int,
        actionCount: Int = 0,
        activeDayCount: Int = 0,
        completedStageCount: Int = 0,
        worlds: [HomeAdventureWorld] = [],
        items: [HomeAdventureItem],
        ownedItemIDs: Set<String>,
        unlockedWorldIDs: Set<String> = [],
        unlockedStageIDs: Set<String> = []
    ) {
        self.totalCoins = totalCoins
        self.actionCount = actionCount
        self.activeDayCount = activeDayCount
        self.completedStageCount = completedStageCount
        self.worlds = worlds
        self.items = items
        self.ownedItemIDs = ownedItemIDs
        self.unlockedWorldIDs = unlockedWorldIDs
        self.unlockedStageIDs = unlockedStageIDs
    }

    var ownedItems: [HomeAdventureItem] {
        items.filter { ownedItemIDs.contains($0.id) }
    }

    var ownedItemCount: Int {
        ownedItems.count
    }

    var unlockedWorlds: [HomeAdventureWorld] {
        worlds.filter { unlockedWorldIDs.contains($0.id) }
    }

    var unlockedWorldCount: Int {
        unlockedWorlds.count
    }

    var unlockedStages: [HomeAdventureStage] {
        worlds.flatMap(\.stages).filter { unlockedStageIDs.contains($0.id) }
    }

    var unlockedStageCount: Int {
        unlockedStages.count
    }

    var spentCoins: Int {
        let itemCoins = ownedItems.reduce(0) { $0 + $1.requiredCoins }
        let worldCoins = unlockedWorlds.reduce(0) { $0 + $1.unlockCost }
        let stageCoins = unlockedStages.reduce(0) { $0 + $1.unlockCost }
        return itemCoins + worldCoins + stageCoins
    }

    var spendableCoins: Int {
        max(0, totalCoins - spentCoins)
    }

    var purchasableItems: [HomeAdventureItem] {
        items.filter { canUnlock($0) }
    }

    var purchasableWorlds: [HomeAdventureWorld] {
        worlds.filter { canUnlock($0) }
    }

    var purchasableStages: [HomeAdventureStage] {
        worlds.flatMap(\.stages).filter { canUnlock($0) }
    }

    var firstPurchasableItem: HomeAdventureItem? {
        purchasableItems.first
    }

    var firstPurchasableWorld: HomeAdventureWorld? {
        purchasableWorlds.first
    }

    var firstPurchasableStage: HomeAdventureStage? {
        purchasableStages.first
    }

    func owns(_ item: HomeAdventureItem) -> Bool {
        ownedItemIDs.contains(item.id)
    }

    func isWorldUnlocked(_ world: HomeAdventureWorld) -> Bool {
        unlockedWorldIDs.contains(world.id)
    }

    func isStageUnlocked(_ stage: HomeAdventureStage) -> Bool {
        unlockedStageIDs.contains(stage.id)
    }

    func canUnlock(_ world: HomeAdventureWorld) -> Bool {
        !isWorldUnlocked(world)
            && world.isEligible(totalCoins: totalCoins, actionCount: actionCount)
            && spendableCoins >= world.unlockCost
    }

    func canUnlock(_ stage: HomeAdventureStage) -> Bool {
        !isStageUnlocked(stage)
            && unlockedWorldIDs.contains(stage.worldID)
            && stage.isEligible
            && spendableCoins >= stage.unlockCost
    }

    func canUnlock(_ item: HomeAdventureItem) -> Bool {
        item.isUnlocked
            && !owns(item)
            && completedStageCount >= item.requiredStageCount
            && spendableCoins >= item.requiredCoins
    }

    func unlockGuidance(for world: HomeAdventureWorld) -> String {
        if isWorldUnlocked(world) {
            return "Unlocked"
        }

        if !world.isEligible(totalCoins: totalCoins, actionCount: actionCount) {
            let gaps = world.missingRequirementSummaries(
                totalCoins: totalCoins,
                actionCount: actionCount
            )
            return gaps.first ?? "Keep earning progress"
        }

        let coinGap = max(0, world.unlockCost - spendableCoins)
        if coinGap > 0 {
            return "Need \(coinGap.formatted()) more spendable coins"
        }

        return world.unlockCost == 0 ? "Ready to choose" : "Ready to unlock"
    }

    func unlockGuidance(for stage: HomeAdventureStage) -> String {
        if isStageUnlocked(stage) {
            return "Unlocked"
        }

        guard unlockedWorldIDs.contains(stage.worldID) else {
            return "Unlock the world first"
        }

        if !stage.isEligible {
            let gaps = stage.missingRequirementSummaries(
                totalCoins: totalCoins,
                actionCount: actionCount,
                activeDayCount: activeDayCount
            )
            return gaps.first ?? "Earn all 3 stars first"
        }

        let coinGap = max(0, stage.unlockCost - spendableCoins)
        if coinGap > 0 {
            return "Need \(coinGap.formatted()) more spendable coins"
        }

        return "Ready to unlock"
    }

    func unlockGuidance(for item: HomeAdventureItem) -> String {
        if owns(item) {
            return "Owned"
        }

        if !item.isUnlocked {
            let stageGap = max(0, item.requiredStageCount - completedStageCount)
            let coinGap = max(0, item.requiredCoins - totalCoins)
            if stageGap > 0 {
                return "Unlock \(stageGap.formatted()) more creature\(stageGap == 1 ? "" : "s")"
            }
            if coinGap > 0 {
                return "Earn \(coinGap.formatted()) more coins"
            }
            return "Keep earning progress"
        }

        let coinGap = max(0, item.requiredCoins - spendableCoins)
        if coinGap > 0 {
            return "Need \(coinGap.formatted()) more spendable coins"
        }

        return "Ready to unlock"
    }
}

enum HomeAdventureOwnedItemIDs {
    static func decode(_ rawValue: String) -> Set<String> {
        Set(
            rawValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    static func encode(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }
}

struct HomeAdventureWorld: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accentName: String
    let artAssetName: String
    let requiredCoins: Int
    let requiredActions: Int
    var stages: [HomeAdventureStage]

    var isUnlocked: Bool {
        stages.contains { $0.status != .locked }
    }

    var clearedStageCount: Int {
        stages.filter { $0.status == .cleared }.count
    }

    var availableStageCount: Int {
        stages.filter { $0.status != .locked }.count
    }

    var unlockCost: Int {
        requiredCoins
    }

    func isEligible(totalCoins: Int, actionCount: Int) -> Bool {
        totalCoins >= requiredCoins && actionCount >= requiredActions
    }

    func missingRequirementSummaries(totalCoins: Int, actionCount: Int) -> [String] {
        var summaries: [String] = []
        let coinGap = max(0, requiredCoins - totalCoins)
        let actionGap = max(0, requiredActions - actionCount)
        if coinGap > 0 {
            summaries.append("\(coinGap.formatted()) more coins")
        }
        if actionGap > 0 {
            summaries.append("\(actionGap.formatted()) more actions")
        }
        return summaries
    }
}

struct HomeAdventureStage: Identifiable, Equatable {
    enum Status: Equatable {
        case locked
        case available
        case cleared
    }

    let id: String
    let worldID: String
    let number: Int
    let title: String
    let subtitle: String
    let requiredCoins: Int
    let requiredActions: Int
    let requiredActiveDays: Int
    let rewardCoins: Int
    let coinStarEarned: Bool
    let actionStarEarned: Bool
    let activeDayStarEarned: Bool
    var status: Status

    var stars: Int {
        [
            coinStarEarned,
            actionStarEarned,
            activeDayStarEarned
        ].filter(\.self).count
    }

    var requirementText: String {
        let coinText = "\(requiredCoins.formatted()) coins"
        let actionText = "\(requiredActions.formatted()) actions"
        let dayText = "\(requiredActiveDays.formatted()) active days"
        return [coinText, actionText, dayText].joined(separator: " | ")
    }

    var unlockCost: Int {
        requiredCoins
    }

    var isEligible: Bool {
        coinStarEarned && actionStarEarned && activeDayStarEarned
    }

    func missingRequirementSummaries(
        totalCoins: Int,
        actionCount: Int,
        activeDayCount: Int
    ) -> [String] {
        var summaries: [String] = []
        let coinGap = max(0, requiredCoins - totalCoins)
        let actionGap = max(0, requiredActions - actionCount)
        let dayGap = max(0, requiredActiveDays - activeDayCount)
        if coinGap > 0 {
            summaries.append("\(coinGap.formatted()) more coins")
        }
        if actionGap > 0 {
            summaries.append("\(actionGap.formatted()) more actions")
        }
        if dayGap > 0 {
            summaries.append("\(dayGap.formatted()) more active days")
        }
        return summaries
    }
}

struct HomeAdventureItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case tool
        case companion
        case artifact
        case booster

        var title: String {
            switch self {
            case .tool:
                return "Tool"
            case .companion:
                return "Companion"
            case .artifact:
                return "Artifact"
            case .booster:
                return "Booster"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let kind: Kind
    let requiredCoins: Int
    let requiredStageCount: Int
    var isUnlocked: Bool
}

struct HomeAdventureCoinSource: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let count: Int
    let coins: Int
    let coinsPerAction: Int
    let unitSingular: String
    let unitPlural: String

    var countText: String {
        "\(count.formatted()) \(count == 1 ? unitSingular : unitPlural)"
    }

    var rateText: String {
        "+\(coinsPerAction.formatted()) each"
    }

    var formulaText: String {
        "\(count.formatted()) x \(coinsPerAction.formatted())"
    }
}

struct HomeAdventureCoinRule: Identifiable, Equatable {
    let id: String
    let actionTitle: String
    let sourceTitle: String
    let systemImage: String
    let unitSingular: String
    let unitPlural: String
    let coinsPerAction: Int

    static let all: [HomeAdventureCoinRule] = [
        HomeAdventureCoinRule(
            id: "done",
            actionTitle: "Complete a task",
            sourceTitle: "Task completions",
            systemImage: "checkmark.seal.fill",
            unitSingular: "completion",
            unitPlural: "completions",
            coinsPerAction: 12
        ),
        HomeAdventureCoinRule(
            id: "created",
            actionTitle: "Create a task",
            sourceTitle: "Created tasks",
            systemImage: "plus.circle.fill",
            unitSingular: "task",
            unitPlural: "tasks",
            coinsPerAction: 5
        ),
        HomeAdventureCoinRule(
            id: "focus",
            actionTitle: "Finish a task focus block",
            sourceTitle: "Task focus blocks",
            systemImage: "timer",
            unitSingular: "block",
            unitPlural: "blocks",
            coinsPerAction: 4
        ),
        HomeAdventureCoinRule(
            id: "boardFocus",
            actionTitle: "Finish a board focus block",
            sourceTitle: "Board focus blocks",
            systemImage: "square.grid.3x3.fill",
            unitSingular: "block",
            unitPlural: "blocks",
            coinsPerAction: 6
        ),
        HomeAdventureCoinRule(
            id: "sleep",
            actionTitle: "Complete sleep",
            sourceTitle: "Completed sleep",
            systemImage: "bed.double.fill",
            unitSingular: "session",
            unitPlural: "sessions",
            coinsPerAction: 25
        ),
        HomeAdventureCoinRule(
            id: "away",
            actionTitle: "Complete away",
            sourceTitle: "Completed away",
            systemImage: "lock.shield.fill",
            unitSingular: "session",
            unitPlural: "sessions",
            coinsPerAction: 16
        ),
        HomeAdventureCoinRule(
            id: "captures",
            actionTitle: "Capture a note, event, or emotion",
            sourceTitle: "Notes, events, emotions",
            systemImage: "sparkles",
            unitSingular: "capture",
            unitPlural: "captures",
            coinsPerAction: 6
        ),
        HomeAdventureCoinRule(
            id: "goals",
            actionTitle: "Create a goal",
            sourceTitle: "Goals",
            systemImage: "target",
            unitSingular: "goal",
            unitPlural: "goals",
            coinsPerAction: 14
        ),
        HomeAdventureCoinRule(
            id: "places",
            actionTitle: "Check in to a place",
            sourceTitle: "Check-ins",
            systemImage: "mappin.and.ellipse",
            unitSingular: "check-in",
            unitPlural: "check-ins",
            coinsPerAction: 10
        )
    ]

    func source(count: Int) -> HomeAdventureCoinSource {
        HomeAdventureCoinSource(
            id: id,
            title: sourceTitle,
            systemImage: systemImage,
            count: count,
            coins: count * coinsPerAction,
            coinsPerAction: coinsPerAction,
            unitSingular: unitSingular,
            unitPlural: unitPlural
        )
    }
}

enum HomeAdventureProgressionBuilder {
    static func build(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        events: [RoutineEvent],
        goals: [RoutineGoal],
        placeCheckInSessions: [PlaceCheckInSession],
        referenceDate: Date,
        calendar: Calendar
    ) -> HomeAdventureProgression {
        let metrics = Metrics(
            tasks: tasks,
            logs: logs,
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            emotionLogs: emotionLogs,
            notes: notes,
            events: events,
            goals: goals,
            placeCheckInSessions: placeCheckInSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let sources = coinSources(from: metrics)
        let totalCoins = sources.reduce(0) { $0 + $1.coins }
        let totalXP = metrics.completedLogCount * 10
            + metrics.createdTaskCount * 4
            + metrics.taskFocusBlockCount * 3
            + metrics.boardFocusBlockCount * 4
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
        let worlds = worldTemplates().map { template in
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
        let items = itemTemplates().map { item in
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
            "sleep": metrics.completedSleepCount,
            "away": metrics.completedAwayCount,
            "captures": metrics.captureActionCount,
            "goals": metrics.goalCount,
            "places": metrics.placeCheckInCount
        ]

        let sources = HomeAdventureCoinRule.all.map { rule in
            rule.source(count: countsByRuleID[rule.id] ?? 0)
        }

        return sources.filter { $0.count > 0 || $0.coins > 0 }
    }

    private static func worldTemplates() -> [WorldTemplate] {
        [
            WorldTemplate(
                id: "morning-meadow",
                title: "Morning Meadow",
                subtitle: "Start the trail with ordinary wins.",
                systemImage: "sun.max.fill",
                accentName: "green",
                artAssetName: "AdventureMorningMeadow",
                requiredCoins: 0,
                requiredActions: 0,
                stages: [
                    StageTemplate("meadow-1", "morning-meadow", 1, "First Steps", "Complete or create anything in Routina.", 50, 2, 1, 20),
                    StageTemplate("meadow-2", "morning-meadow", 2, "Checklist Nook", "Turn repeated effort into coins.", 150, 8, 2, 30),
                    StageTemplate("meadow-3", "morning-meadow", 3, "Focus Pond", "Mix focus blocks with task progress.", 300, 18, 4, 40),
                    StageTemplate("meadow-4", "morning-meadow", 4, "Habit Gate", "Build several active days.", 550, 35, 7, 55),
                    StageTemplate("meadow-5", "morning-meadow", 5, "Tag Grove", "Organized tasks push the trail forward.", 850, 55, 10, 70),
                    StageTemplate("meadow-6", "morning-meadow", 6, "Meadow Gate", "Clear the first map with steady history.", 1_200, 80, 14, 90)
                ]
            ),
            WorldTemplate(
                id: "clockwork-city",
                title: "Clockwork City",
                subtitle: "Unlock deeper encounters with steady output.",
                systemImage: "gearshape.2.fill",
                accentName: "blue",
                artAssetName: "AdventureClockworkCity",
                requiredCoins: 480,
                requiredActions: 24,
                stages: [
                    StageTemplate("city-1", "clockwork-city", 7, "Planning Station", "More actions open the second map.", 1_700, 110, 18, 110),
                    StageTemplate("city-2", "clockwork-city", 8, "Momentum Rails", "Keep productive days connected.", 2_300, 145, 23, 130),
                    StageTemplate("city-3", "clockwork-city", 9, "Deep Work Tower", "Longer focus history powers the tower.", 3_000, 185, 29, 150),
                    StageTemplate("city-4", "clockwork-city", 10, "Workshop Bridge", "Use captures and completions together.", 3_800, 230, 36, 175),
                    StageTemplate("city-5", "clockwork-city", 11, "Signal Market", "More kinds of Routina activity become fuel.", 4_700, 285, 44, 205),
                    StageTemplate("city-6", "clockwork-city", 12, "Clockwork Gate", "Finish the city by proving consistency.", 5_800, 350, 53, 240)
                ]
            ),
            WorldTemplate(
                id: "lunar-archive",
                title: "Lunar Archive",
                subtitle: "Late-game encounters for a broad Routina history.",
                systemImage: "moon.stars.fill",
                accentName: "indigo",
                artAssetName: "AdventureLunarArchive",
                requiredCoins: 1_600,
                requiredActions: 76,
                stages: [
                    StageTemplate("lunar-1", "lunar-archive", 13, "Quiet Launch", "Unlock the archive with broad consistency.", 7_200, 430, 64, 280),
                    StageTemplate("lunar-2", "lunar-archive", 14, "Memory Vault", "Captured thoughts become map progress.", 8_800, 520, 76, 330),
                    StageTemplate("lunar-3", "lunar-archive", 15, "Starlit Sprint", "A larger action history lights the archive.", 10_600, 620, 90, 390),
                    StageTemplate("lunar-4", "lunar-archive", 16, "Moonlit Library", "Balance focus, notes, sleep, and tasks.", 12_600, 735, 105, 460),
                    StageTemplate("lunar-5", "lunar-archive", 17, "Orbit Hall", "A long-lived routine history opens the hall.", 15_000, 865, 122, 540),
                    StageTemplate("lunar-6", "lunar-archive", 18, "Archive Gate", "Clear the archive with mature momentum.", 17_800, 1_010, 140, 640)
                ]
            ),
            WorldTemplate(
                id: "aurora-peaks",
                title: "Aurora Peaks",
                subtitle: "High-altitude stages for long-term mastery.",
                systemImage: "mountain.2.fill",
                accentName: "mint",
                artAssetName: "AdventureAuroraPeaks",
                requiredCoins: 21_200,
                requiredActions: 1_180,
                stages: [
                    StageTemplate("peaks-1", "aurora-peaks", 19, "Snowline Camp", "The fourth world starts after a real season.", 21_200, 1_180, 160, 760),
                    StageTemplate("peaks-2", "aurora-peaks", 20, "Glacier Steps", "Keep the active-day trail alive.", 25_000, 1_375, 182, 900),
                    StageTemplate("peaks-3", "aurora-peaks", 21, "Aurora Ridge", "Deep progress lights up the ridge.", 29_400, 1_590, 206, 1_060),
                    StageTemplate("peaks-4", "aurora-peaks", 22, "Summit Forge", "A larger system of habits carries upward.", 34_400, 1_830, 232, 1_240),
                    StageTemplate("peaks-5", "aurora-peaks", 23, "Northern Pass", "Cross the pass with durable output.", 40_000, 2_100, 260, 1_460),
                    StageTemplate("peaks-6", "aurora-peaks", 24, "Aurora Gate", "Complete the peaks with long-run consistency.", 46_500, 2_400, 290, 1_720)
                ]
            ),
            WorldTemplate(
                id: "nebula-forge",
                title: "Nebula Forge",
                subtitle: "Endgame work for a serious Routina history.",
                systemImage: "sparkles.rectangle.stack.fill",
                accentName: "pink",
                artAssetName: "AdventureNebulaForge",
                requiredCoins: 54_000,
                requiredActions: 2_750,
                stages: [
                    StageTemplate("forge-1", "nebula-forge", 25, "Ignition Bay", "Open the forge after sustained months.", 54_000, 2_750, 323, 2_000),
                    StageTemplate("forge-2", "nebula-forge", 26, "Star Anvil", "Shape the long arc of your routines.", 62_500, 3_150, 360, 2_350),
                    StageTemplate("forge-3", "nebula-forge", 27, "Plasma Loom", "High-volume action history powers the loom.", 72_000, 3_600, 400, 2_750),
                    StageTemplate("forge-4", "nebula-forge", 28, "Comet Foundry", "Cross from productivity into endurance.", 83_000, 4_100, 444, 3_200),
                    StageTemplate("forge-5", "nebula-forge", 29, "Nebula Crown", "The final map asks for rare consistency.", 95_500, 4_650, 492, 3_750),
                    StageTemplate("forge-6", "nebula-forge", 30, "World Engine", "Finish the first long-form Adventure season.", 110_000, 5_250, 545, 4_400)
                ]
            )
        ]
    }

    private static func itemTemplates() -> [ItemTemplate] {
        [
            ItemTemplate("trail-compass", "Trail Compass", "Unlocked after the first few wins.", "location.north.line.fill", .tool, 200, 1),
            ItemTemplate("meadow-guide", "Meadow Guide", "A tiny guide for the first map.", "sun.max.fill", .companion, 900, 4),
            ItemTemplate("focus-lantern", "Focus Lantern", "A badge for showing up to focus.", "lamp.desk.fill", .tool, 1_900, 7),
            ItemTemplate("quiet-keeper", "Quiet Keeper", "A calm character for balanced routines.", "sparkles", .companion, 3_500, 10),
            ItemTemplate("city-banner", "City Banner", "Marks the second-world clear.", "flag.checkered", .artifact, 6_000, 12),
            ItemTemplate("lunar-key", "Lunar Key", "Signals entry into the archive.", "key.fill", .artifact, 11_000, 15),
            ItemTemplate("archive-cloak", "Archive Cloak", "A late archive artifact.", "theatermasks.fill", .artifact, 18_500, 18),
            ItemTemplate("aurora-pickaxe", "Aurora Pickaxe", "A tool for the high mountain climb.", "hammer.fill", .tool, 30_000, 21),
            ItemTemplate("summit-banner", "Summit Banner", "A trophy from Aurora Peaks.", "flag.2.crossed.fill", .artifact, 47_000, 24),
            ItemTemplate("forge-core", "Forge Core", "The first endgame booster.", "atom", .booster, 65_000, 26),
            ItemTemplate("nebula-crown", "Nebula Crown", "A rare long-run artifact.", "crown.fill", .artifact, 86_000, 28),
            ItemTemplate("world-engine", "World Engine", "The first Adventure season capstone.", "infinity.circle.fill", .artifact, 110_000, 30)
        ]
    }
}

private struct WorldTemplate {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accentName: String
    let artAssetName: String
    let requiredCoins: Int
    let requiredActions: Int
    let stages: [StageTemplate]
}

private struct StageTemplate {
    let id: String
    let worldID: String
    let number: Int
    let title: String
    let subtitle: String
    let requiredCoins: Int
    let requiredActions: Int
    let requiredActiveDays: Int
    let rewardCoins: Int

    init(
        _ id: String,
        _ worldID: String,
        _ number: Int,
        _ title: String,
        _ subtitle: String,
        _ requiredCoins: Int,
        _ requiredActions: Int,
        _ requiredActiveDays: Int,
        _ rewardCoins: Int
    ) {
        self.id = id
        self.worldID = worldID
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.requiredCoins = requiredCoins
        self.requiredActions = requiredActions
        self.requiredActiveDays = requiredActiveDays
        self.rewardCoins = rewardCoins
    }
}

private struct ItemTemplate {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let kind: HomeAdventureItem.Kind
    let requiredCoins: Int
    let requiredStageCount: Int

    init(
        _ id: String,
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        _ kind: HomeAdventureItem.Kind,
        _ requiredCoins: Int,
        _ requiredStageCount: Int
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.kind = kind
        self.requiredCoins = requiredCoins
        self.requiredStageCount = requiredStageCount
    }
}

private struct Metrics {
    let completedLogCount: Int
    let createdTaskCount: Int
    let taskFocusBlockCount: Int
    let boardFocusBlockCount: Int
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
            + completedSleepCount
            + completedAwayCount
            + captureActionCount
            + goalCount
            + placeCheckInCount
    }

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        events: [RoutineEvent],
        goals: [RoutineGoal],
        placeCheckInSessions: [PlaceCheckInSession],
        referenceDate: Date,
        calendar: Calendar
    ) {
        completedLogCount = logs.filter { $0.kind == .completed }.count
        createdTaskCount = tasks.filter { $0.createdAt != nil }.count
        let taskFocusSeconds = focusSessions.reduce(0) { total, session in
            total + session.activeDurationSeconds(at: referenceDate)
        }
        let boardFocusSeconds = sprintFocusSessions.reduce(0) { total, session in
            total + session.activeDurationSeconds(at: referenceDate)
        }
        taskFocusBlockCount = FocusBlockProgress.filledBlockCount(for: taskFocusSeconds)
        boardFocusBlockCount = FocusBlockProgress.filledBlockCount(for: boardFocusSeconds)
        completedSleepCount = sleepSessions.filter { !$0.isActive }.count
        completedAwayCount = awaySessions.filter { $0.state == .completed }.count
        captureActionCount = emotionLogs.count + notes.count + events.count
        goalCount = goals.count
        placeCheckInCount = placeCheckInSessions.count

        var activeDays = Set<Date>()
        func insertDay(_ date: Date?) {
            guard let date else { return }
            activeDays.insert(calendar.startOfDay(for: date))
        }
        logs.forEach { insertDay($0.timestamp) }
        tasks.forEach { insertDay($0.createdAt) }
        focusSessions.forEach { insertDay($0.startedAt) }
        sprintFocusSessions.forEach { insertDay($0.startedAt) }
        sleepSessions.forEach { insertDay($0.startedAt) }
        awaySessions.forEach { insertDay($0.startedAt) }
        emotionLogs.forEach { insertDay($0.createdAt) }
        notes.forEach { insertDay($0.createdAt) }
        events.forEach { insertDay($0.startedAt ?? $0.createdAt) }
        goals.forEach { insertDay($0.createdAt) }
        placeCheckInSessions.forEach { insertDay($0.startedAt ?? $0.createdAt) }
        activeDayCount = activeDays.count
    }
}
