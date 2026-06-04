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

        let progression = HomeAdventureProgressionBuilder.build(
            tasks: [taskA, taskB],
            logs: logs,
            focusSessions: [focusSession],
            sprintFocusSessions: [sprintFocusSession],
            sleepSessions: [sleepSession],
            awaySessions: [awaySession],
            emotionLogs: [emotion],
            notes: [note],
            events: [event],
            goals: [goal],
            placeCheckInSessions: [checkIn],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(progression.totalCoins == 157)
        #expect(progression.actionCount == 19)
        #expect(progression.activeDayCount == 3)
        #expect(progression.level == 1)
        #expect(progression.completedStageCount == 2)
        #expect(progression.sources.map(\.id) == [
            "done",
            "created",
            "focus",
            "sleep",
            "away",
            "captures",
            "goals",
            "places"
        ])
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
