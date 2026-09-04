import SwiftUI

struct HomeMacAdventureSidebarView: View {
    let progression: HomeAdventureProgression
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue, store: SharedDefaults.app)
    private var isAwayEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue, store: SharedDefaults.app)
    private var isNotesEnabled = false
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureOwnedItemIDs.rawValue, store: SharedDefaults.app)
    private var ownedItemIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureUnlockedWorldIDs.rawValue, store: SharedDefaults.app)
    private var unlockedWorldIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureUnlockedStageIDs.rawValue, store: SharedDefaults.app)
    private var unlockedStageIDsRaw = ""

    private var ownedItemIDs: Set<String> {
        HomeAdventureOwnedItemIDs.decode(ownedItemIDsRaw)
    }

    private var unlockedWorldIDs: Set<String> {
        HomeAdventureOwnedItemIDs.decode(unlockedWorldIDsRaw)
    }

    private var unlockedStageIDs: Set<String> {
        HomeAdventureOwnedItemIDs.decode(unlockedStageIDsRaw)
    }

    private var wallet: HomeAdventureWallet {
        HomeAdventureWallet(
            totalCoins: progression.totalCoins,
            actionCount: progression.actionCount,
            activeDayCount: progression.activeDayCount,
            completedStageCount: unlockedStageCount,
            worlds: progression.worlds,
            items: progression.items,
            ownedItemIDs: ownedItemIDs,
            unlockedWorldIDs: unlockedWorldIDs,
            unlockedStageIDs: unlockedStageIDs
        )
    }

    private var totalStageCount: Int {
        progression.worlds.flatMap(\.stages).count
    }

    private var unlockedStageCount: Int {
        progression.worlds.flatMap(\.stages).filter { unlockedStageIDs.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Adventure", systemImage: "map.fill")
                        .font(.headline)

                    HStack(spacing: 8) {
                        HomeAdventureSidebarMetric(
                            title: "Spendable",
                            value: wallet.spendableCoins.formatted(),
                            systemImage: "circle.hexagongrid.fill"
                        )
                        HomeAdventureSidebarMetric(
                            title: "Inventory",
                            value: "\(wallet.ownedItemCount)/\(progression.items.count)",
                            systemImage: "backpack.fill"
                        )
                    }

                    HStack(spacing: 8) {
                        HomeAdventureSidebarMetric(
                            title: "XP Rank",
                            value: "\(progression.level)",
                            systemImage: "sparkles"
                        )
                        HomeAdventureSidebarMetric(
                            title: "Creatures",
                            value: "\(wallet.unlockedStageCount)/\(totalStageCount)",
                            systemImage: "flag.checkered"
                        )
                    }

                    ProgressView(value: progression.levelProgress)
                        .tint(.yellow)
                    Text(
                        "\(progression.currentRankXP.formatted()) / \(HomeAdventureProgression.xpPerRank.formatted()) XP to Rank \(progression.nextRank)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let world = wallet.firstPurchasableWorld {
                    HomeAdventureSidebarWorldCard(
                        title: wallet.purchasableWorlds.count == 1 ? "Ready World" : "Ready Worlds",
                        world: world,
                        wallet: wallet,
                        readyCount: wallet.purchasableWorlds.count
                    )
                }

                if let stage = wallet.firstPurchasableStage {
                    HomeAdventureSidebarStageCard(
                        title: wallet.purchasableStages.count == 1 ? "Ready Creature" : "Ready Creatures",
                        stage: stage,
                        wallet: wallet,
                        readyCount: wallet.purchasableStages.count
                    )
                }

                if let item = wallet.firstPurchasableItem {
                    HomeAdventureSidebarItemCard(
                        item: item,
                        wallet: wallet,
                        readyCount: wallet.purchasableItems.count
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Coin Sources")
                        .font(.subheadline.weight(.semibold))

                    if progression.sources.isEmpty {
                        Text(emptyCoinSourcesText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(progression.sources) { source in
                            HStack(spacing: 8) {
                                Image(systemName: source.systemImage)
                                    .foregroundStyle(.yellow)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.title)
                                        .font(.caption.weight(.medium))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(source.countText) at \(source.rateText)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .layoutPriority(1)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("+\(source.coins.formatted())")
                                        .font(.caption.weight(.semibold))
                                    Text(source.formulaText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .fixedSize()
                            }
                        }
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(14)
        }
    }

    private var emptyCoinSourcesText: String {
        var actions = ["Complete tasks", "focus"]
        if isNotesEnabled {
            actions.append("capture notes")
        }
        actions.append("log emotions")
        if isPlacesEnabled {
            actions.append("check in")
        }
        if isAwayEnabled {
            actions.append("sleep")
        }
        if isAwayEnabled {
            actions.append("finish away sessions")
        }
        return "\(Self.listText(actions)) to start earning."
    }

    private static func listText(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) or \(items[1])"
        default:
            return items.dropLast().joined(separator: ", ") + ", or \(items.last ?? "")"
        }
    }
}
