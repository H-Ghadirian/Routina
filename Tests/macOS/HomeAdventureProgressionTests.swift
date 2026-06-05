import Foundation
import Testing
@testable import RoutinaMacOSDev

@MainActor
struct HomeAdventureProgressionTests {
    @Test
    func build_awardsCoinsForMacActivitySources() {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let yesterday = referenceDate.addingTimeInterval(-86_400)
        let twoDaysAgo = referenceDate.addingTimeInterval(-172_800)
        let taskA = RoutineTask(id: UUID(), name: "Morning", createdAt: twoDaysAgo)
        let taskB = RoutineTask(id: UUID(), name: "Read", createdAt: yesterday)
        let logs = [
            RoutineLog(timestamp: twoDaysAgo, taskID: taskA.id, kind: .completed),
            RoutineLog(timestamp: yesterday, taskID: taskA.id, kind: .completed),
            RoutineLog(timestamp: referenceDate, taskID: taskB.id, kind: .completed),
            RoutineLog(timestamp: referenceDate, taskID: taskB.id, kind: .missed)
        ]
        let focusSession = FocusSession(
            taskID: taskA.id,
            startedAt: referenceDate.addingTimeInterval(-25 * 60),
            completedAt: referenceDate
        )
        let sprintFocusSession = SprintFocusSessionRecord(
            sprintID: UUID(),
            startedAt: referenceDate.addingTimeInterval(-10 * 60),
            stoppedAt: referenceDate
        )
        let sleepSession = SleepSession(
            startedAt: yesterday,
            endedAt: referenceDate,
            createdAt: yesterday,
            updatedAt: referenceDate
        )
        let awaySession = AwaySession(
            startedAt: referenceDate.addingTimeInterval(-20 * 60),
            plannedDurationSeconds: 20 * 60,
            completedAt: referenceDate
        )
        let emotion = EmotionLog(
            family: .calm,
            label: EmotionFamily.calm.defaultLabel,
            valence: 0,
            arousal: 0,
            intensity: 3,
            createdAt: referenceDate
        )
        let note = RoutineNote(title: "Idea", createdAt: referenceDate)
        let event = RoutineEvent(title: "Review", startedAt: referenceDate, createdAt: referenceDate)
        let goal = RoutineGoal(title: "Ship MVP", createdAt: twoDaysAgo)
        let checkIn = PlaceCheckInSession(
            placeID: UUID(),
            placeName: "Desk",
            startedAt: yesterday,
            endedAt: referenceDate,
            createdAt: yesterday
        )
        let refinedPlannerBlock = DayPlanBlockRecord(
            taskID: taskA.id,
            dayKey: DayPlanStorage.dayKey(for: twoDaysAgo, calendar: calendar),
            startMinute: 9 * 60,
            durationMinutes: 90,
            titleSnapshot: "Morning",
            createdAt: twoDaysAgo,
            updatedAt: yesterday
        )
        let plannerBlock = DayPlanBlockRecord(
            taskID: taskB.id,
            dayKey: DayPlanStorage.dayKey(for: referenceDate, calendar: calendar),
            startMinute: 14 * 60,
            durationMinutes: 30,
            titleSnapshot: "Read",
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let progression = HomeAdventureProgressionBuilder.build(
            tasks: [taskA, taskB],
            logs: logs,
            focusSessions: [focusSession],
            sprintFocusSessions: [sprintFocusSession],
            sleepSessions: [sleepSession],
            awaySessions: [awaySession],
            dayPlanBlocks: [refinedPlannerBlock, plannerBlock],
            emotionLogs: [emotion],
            notes: [note],
            events: [event],
            goals: [goal],
            placeCheckInSessions: [checkIn],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(progression.totalCoins == 175)
        #expect(progression.actionCount == 24)
        #expect(progression.activeDayCount == 3)
        #expect(progression.level == 1)
        #expect(progression.completedStageCount == 2)
        #expect(progression.sources.map(\.id) == [
            "done",
            "created",
            "focus",
            "boardFocus",
            "plannerBlocks",
            "plannedHours",
            "plannerRefinements",
            "sleep",
            "away",
            "captures",
            "goals",
            "places"
        ])
        #expect(progression.sources.first { $0.id == "done" }?.coinsPerAction == 12)
        #expect(progression.sources.first { $0.id == "done" }?.countText == "3 completions")
        #expect(progression.sources.first { $0.id == "done" }?.formulaText == "3 x 12")
        #expect(progression.sources.first { $0.id == "focus" }?.countText == "5 blocks")
        #expect(progression.sources.first { $0.id == "boardFocus" }?.countText == "2 blocks")
        #expect(progression.sources.first { $0.id == "boardFocus" }?.coins == 12)
        #expect(progression.sources.first { $0.id == "plannerBlocks" }?.countText == "2 blocks")
        #expect(progression.sources.first { $0.id == "plannedHours" }?.countText == "2 hours")
        #expect(progression.sources.first { $0.id == "plannerRefinements" }?.countText == "1 refinement")
        #expect(HomeAdventureCoinRule.all.map(\.coinsPerAction) == [12, 5, 4, 6, 4, 2, 2, 25, 16, 6, 14, 10])
    }

    @Test
    func build_keepsLaterWorldsAndItemsLockedUntilProgressIsEarned() {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

        let progression = HomeAdventureProgressionBuilder.build(
            tasks: [],
            logs: [],
            focusSessions: [],
            sprintFocusSessions: [],
            sleepSessions: [],
            awaySessions: [],
            dayPlanBlocks: [],
            emotionLogs: [],
            notes: [],
            events: [],
            goals: [],
            placeCheckInSessions: [],
            referenceDate: referenceDate,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(progression.totalCoins == 0)
        #expect(progression.actionCount == 0)
        #expect(progression.completedStageCount == 0)
        #expect(progression.unlockedWorldCount == 0)
        #expect(progression.unlockedItemCount == 0)
        #expect(progression.worlds.first?.stages.first?.status == .locked)
        #expect(progression.nextLockedStage?.title == "First Steps")
    }

    @Test
    func wallet_countsSpendableCoinsForChosenOwnedItems() {
        let items = [
            HomeAdventureItem(
                id: "starter",
                title: "Starter",
                subtitle: "First item",
                systemImage: "sparkles",
                kind: .tool,
                requiredCoins: 200,
                requiredStageCount: 1,
                isUnlocked: true
            ),
            HomeAdventureItem(
                id: "guide",
                title: "Guide",
                subtitle: "Choice item",
                systemImage: "sun.max.fill",
                kind: .companion,
                requiredCoins: 900,
                requiredStageCount: 4,
                isUnlocked: true
            ),
            HomeAdventureItem(
                id: "late",
                title: "Late",
                subtitle: "Locked item",
                systemImage: "lock.fill",
                kind: .artifact,
                requiredCoins: 1_200,
                requiredStageCount: 8,
                isUnlocked: false
            )
        ]
        let ownedIDs = HomeAdventureOwnedItemIDs.decode("starter,missing,starter")
        let wallet = HomeAdventureWallet(
            totalCoins: 1_000,
            completedStageCount: 4,
            items: items,
            ownedItemIDs: ownedIDs
        )

        #expect(ownedIDs == Set(["starter", "missing"]))
        #expect(HomeAdventureOwnedItemIDs.encode(ownedIDs) == "missing,starter")
        #expect(wallet.ownedItemCount == 1)
        #expect(wallet.spentCoins == 200)
        #expect(wallet.spendableCoins == 800)
        #expect(wallet.canUnlock(items[1]) == false)
        #expect(wallet.unlockGuidance(for: items[1]) == "Need 100 more spendable coins")
        #expect(wallet.unlockGuidance(for: items[2]) == "Unlock 4 more creatures")

        let richerWallet = HomeAdventureWallet(
            totalCoins: 1_200,
            completedStageCount: 4,
            items: items,
            ownedItemIDs: ownedIDs
        )

        #expect(richerWallet.canUnlock(items[1]) == true)
    }

    @Test
    func wallet_requiresExplicitWorldAndCreatureChoices() {
        let stage = HomeAdventureStage(
            id: "meadow-1",
            worldID: "morning-meadow",
            number: 1,
            title: "First Steps",
            subtitle: "Complete or create anything in Routina.",
            requiredCoins: 50,
            requiredActions: 2,
            requiredActiveDays: 1,
            rewardCoins: 20,
            coinStarEarned: true,
            actionStarEarned: true,
            activeDayStarEarned: true,
            status: .cleared
        )
        let world = HomeAdventureWorld(
            id: "morning-meadow",
            title: "Morning Meadow",
            subtitle: "Start the trail with ordinary wins.",
            systemImage: "sun.max.fill",
            accentName: "green",
            artAssetName: "AdventureMorningMeadow",
            requiredCoins: 0,
            requiredActions: 0,
            stages: [stage]
        )

        let freshWallet = HomeAdventureWallet(
            totalCoins: 200,
            actionCount: 10,
            activeDayCount: 3,
            worlds: [world],
            items: [],
            ownedItemIDs: []
        )

        #expect(freshWallet.unlockedWorldCount == 0)
        #expect(freshWallet.unlockedStageCount == 0)
        #expect(freshWallet.canUnlock(world) == true)
        #expect(freshWallet.canUnlock(stage) == false)
        #expect(freshWallet.unlockGuidance(for: stage) == "Unlock the world first")

        let worldWallet = HomeAdventureWallet(
            totalCoins: 200,
            actionCount: 10,
            activeDayCount: 3,
            worlds: [world],
            items: [],
            ownedItemIDs: [],
            unlockedWorldIDs: ["morning-meadow"]
        )

        #expect(worldWallet.unlockedWorldCount == 1)
        #expect(worldWallet.unlockedStageCount == 0)
        #expect(worldWallet.spendableCoins == 200)
        #expect(worldWallet.canUnlock(stage) == true)

        let creatureWallet = HomeAdventureWallet(
            totalCoins: 200,
            actionCount: 10,
            activeDayCount: 3,
            completedStageCount: 1,
            worlds: [world],
            items: [],
            ownedItemIDs: [],
            unlockedWorldIDs: ["morning-meadow"],
            unlockedStageIDs: ["meadow-1"]
        )

        #expect(creatureWallet.unlockedStageCount == 1)
        #expect(creatureWallet.spentCoins == 50)
        #expect(creatureWallet.spendableCoins == 150)
        #expect(creatureWallet.canUnlock(stage) == false)
        #expect(creatureWallet.unlockGuidance(for: stage) == "Unlocked")
    }

    @Test
    func wallet_allowsReadyWorldsAndCreaturesToBeChosenOutOfOrder() {
        func stage(
            id: String,
            worldID: String,
            number: Int,
            title: String,
            requiredCoins: Int
        ) -> HomeAdventureStage {
            HomeAdventureStage(
                id: id,
                worldID: worldID,
                number: number,
                title: title,
                subtitle: "Ready creature",
                requiredCoins: requiredCoins,
                requiredActions: 4,
                requiredActiveDays: 2,
                rewardCoins: 20,
                coinStarEarned: true,
                actionStarEarned: true,
                activeDayStarEarned: true,
                status: .cleared
            )
        }

        let firstWorld = HomeAdventureWorld(
            id: "morning-meadow",
            title: "Morning Meadow",
            subtitle: "Starter world",
            systemImage: "sun.max.fill",
            accentName: "green",
            artAssetName: "AdventureMorningMeadow",
            requiredCoins: 0,
            requiredActions: 0,
            stages: [
                stage(
                    id: "meadow-1",
                    worldID: "morning-meadow",
                    number: 1,
                    title: "First Steps",
                    requiredCoins: 50
                )
            ]
        )
        let laterWorld = HomeAdventureWorld(
            id: "lunar-archive",
            title: "Lunar Archive",
            subtitle: "Later world",
            systemImage: "moon.stars.fill",
            accentName: "purple",
            artAssetName: "AdventureLunarArchive",
            requiredCoins: 500,
            requiredActions: 8,
            stages: [
                stage(
                    id: "archive-1",
                    worldID: "lunar-archive",
                    number: 13,
                    title: "Quiet Launch",
                    requiredCoins: 100
                ),
                stage(
                    id: "archive-2",
                    worldID: "lunar-archive",
                    number: 14,
                    title: "Memory Vault",
                    requiredCoins: 300
                )
            ]
        )
        let worlds = [firstWorld, laterWorld]

        let freshWallet = HomeAdventureWallet(
            totalCoins: 1_000,
            actionCount: 50,
            activeDayCount: 10,
            worlds: worlds,
            items: [],
            ownedItemIDs: []
        )

        #expect(freshWallet.purchasableWorlds.map(\.id) == ["morning-meadow", "lunar-archive"])
        #expect(freshWallet.canUnlock(laterWorld) == true)
        #expect(freshWallet.canUnlock(laterWorld.stages[1]) == false)

        let laterWorldWallet = HomeAdventureWallet(
            totalCoins: 1_000,
            actionCount: 50,
            activeDayCount: 10,
            worlds: worlds,
            items: [],
            ownedItemIDs: [],
            unlockedWorldIDs: ["lunar-archive"]
        )

        #expect(laterWorldWallet.isWorldUnlocked(laterWorld) == true)
        #expect(laterWorldWallet.isWorldUnlocked(firstWorld) == false)
        #expect(laterWorldWallet.purchasableStages.map(\.id) == ["archive-1", "archive-2"])
        #expect(laterWorldWallet.canUnlock(laterWorld.stages[1]) == true)

        let skippedCreatureWallet = HomeAdventureWallet(
            totalCoins: 1_000,
            actionCount: 50,
            activeDayCount: 10,
            worlds: worlds,
            items: [],
            ownedItemIDs: [],
            unlockedWorldIDs: ["lunar-archive"],
            unlockedStageIDs: ["archive-2"]
        )

        #expect(skippedCreatureWallet.isStageUnlocked(laterWorld.stages[1]) == true)
        #expect(skippedCreatureWallet.isStageUnlocked(laterWorld.stages[0]) == false)
        #expect(skippedCreatureWallet.canUnlock(laterWorld.stages[0]) == true)
    }

    @Test
    func build_keepsSevenThousandCoinsInMidgame() {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let taskID = UUID()
        let logs = (0..<584).map { index in
            RoutineLog(
                timestamp: referenceDate.addingTimeInterval(-Double(index % 70) * 86_400),
                taskID: taskID,
                kind: .completed
            )
        }

        let progression = HomeAdventureProgressionBuilder.build(
            tasks: [],
            logs: logs,
            focusSessions: [],
            sprintFocusSessions: [],
            sleepSessions: [],
            awaySessions: [],
            dayPlanBlocks: [],
            emotionLogs: [],
            notes: [],
            events: [],
            goals: [],
            placeCheckInSessions: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(progression.totalCoins == 7_008)
        #expect(progression.completedStageCount == 12)
        #expect(progression.worlds.flatMap(\.stages).count == 30)
        #expect(progression.nextLockedStage?.number == 13)
        #expect(progression.nextLockedStage?.coinStarEarned == false)
        #expect(progression.nextLockedStage?.actionStarEarned == true)
        #expect(progression.nextLockedStage?.activeDayStarEarned == true)
        #expect(progression.nextLockedStage?.stars == 2)
        #expect(progression.unlockedItemCount == 5)
    }
}
