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
            activeDayStarEarned,
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
    enum Kind: String, Codable, Equatable {
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

struct HomeAdventureCoinRule: Codable, Identifiable, Equatable {
    let id: String
    let actionTitle: String
    let sourceTitle: String
    let systemImage: String
    let unitSingular: String
    let unitPlural: String
    let coinsPerAction: Int

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
