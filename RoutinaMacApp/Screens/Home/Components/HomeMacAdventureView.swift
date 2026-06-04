import SwiftUI

struct HomeMacAdventureSidebarView: View {
    let progression: HomeAdventureProgression
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
                    Text("\(progression.currentRankXP.formatted()) / \(HomeAdventureProgression.xpPerRank.formatted()) XP to Rank \(progression.nextRank)")
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
                        Text("Complete tasks, focus, capture notes, log emotions, check in, sleep, or finish away sessions to start earning.")
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
                                    Text("\(source.count.formatted()) actions")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(source.coins.formatted())")
                                    .font(.caption.weight(.semibold))
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
}

struct HomeMacAdventureView: View {
    let progression: HomeAdventureProgression
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureOwnedItemIDs.rawValue, store: SharedDefaults.app)
    private var ownedItemIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureUnlockedWorldIDs.rawValue, store: SharedDefaults.app)
    private var unlockedWorldIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureUnlockedStageIDs.rawValue, store: SharedDefaults.app)
    private var unlockedStageIDsRaw = ""

    private let itemColumns = [
        GridItem(.adaptive(minimum: 230), spacing: 12)
    ]

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

    private var totalWorldCount: Int {
        progression.worlds.count
    }

    private var totalStageCount: Int {
        progression.worlds.flatMap(\.stages).count
    }

    private var unlockedStageCount: Int {
        progression.worlds.flatMap(\.stages).filter { unlockedStageIDs.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                HomeAdventureGuideStrip(wallet: wallet)
                worldsSection
                itemsSection
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(adventureBackground)
        .navigationTitle("Adventure")
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.56),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    if let world = heroWorld {
                        HomeAdventureWorldMedallion(
                            creatureSheetAssetName: "\(world.artAssetName)Creatures",
                            isUnlocked: wallet.isWorldUnlocked(world),
                            size: 58
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adventure Map")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.52), radius: 2, y: 1)
                        Text("Earn coins from real routine progress, then choose which companions and artifacts to unlock.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        Text(heroWorldStatusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.42))
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    HomeAdventureMetricTile(
                        title: "Spendable Coins",
                        value: wallet.spendableCoins.formatted(),
                        detail: "Budget for unlock choices",
                        systemImage: "circle.hexagongrid.fill",
                        tint: .yellow
                    )
                    HomeAdventureMetricTile(
                        title: "XP Rank",
                        value: "\(progression.level)",
                        detail: "\(progression.totalXP.formatted()) total XP",
                        systemImage: "sparkles",
                        tint: .purple
                    )
                    HomeAdventureMetricTile(
                        title: "Creatures Unlocked",
                        value: "\(wallet.unlockedStageCount)/\(totalStageCount)",
                        detail: "Chosen creature companions",
                        systemImage: "flag.checkered",
                        tint: .green
                    )
                    HomeAdventureMetricTile(
                        title: "Inventory",
                        value: "\(wallet.ownedItemCount)/\(progression.items.count)",
                        detail: "Artifacts and tools owned",
                        systemImage: "backpack.fill",
                        tint: .orange
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("XP toward Rank \(progression.nextRank)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("\(progression.currentRankXP.formatted()) / \(HomeAdventureProgression.xpPerRank.formatted()) XP")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    ProgressView(value: progression.levelProgress)
                        .tint(.yellow)
                }
            }
            .padding(18)
        }
        .background {
            if let world = heroWorld {
                HomeAdventureWorldArt(assetName: world.artAssetName, isUnlocked: wallet.isWorldUnlocked(world))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var heroWorld: HomeAdventureWorld? {
        wallet.unlockedWorlds.last
            ?? wallet.firstPurchasableWorld
            ?? progression.worlds.first
    }

    private var heroWorldStatusText: String {
        if let world = wallet.unlockedWorlds.last {
            return "Chosen world: \(world.title)"
        }
        let purchasableWorlds = wallet.purchasableWorlds
        if purchasableWorlds.count > 1 {
            return "\(purchasableWorlds.count) worlds ready to choose"
        }
        if let world = purchasableWorlds.first {
            return "World ready to choose: \(world.title)"
        }
        return "\(wallet.unlockedWorldCount)/\(totalWorldCount) worlds chosen"
    }

    private var worldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Worlds")
                .font(.title3.weight(.bold))

            ForEach(progression.worlds) { world in
                HomeAdventureWorldSection(
                    world: world,
                    progression: progression,
                    wallet: wallet,
                    onUnlockWorld: { unlock(world) },
                    onUnlockStage: { unlock($0) }
                )
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items")
                    .font(.title3.weight(.bold))
                Spacer()
                Label("\(wallet.spendableCoins.formatted()) spendable", systemImage: "circle.hexagongrid.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }

            LazyVGrid(columns: itemColumns, alignment: .leading, spacing: 12) {
                ForEach(displayedItems) { item in
                    HomeAdventureItemCard(
                        item: item,
                        wallet: wallet,
                        onUnlock: { unlock(item) }
                    )
                }
            }
        }
    }

    private var displayedItems: [HomeAdventureItem] {
        progression.items.sorted { lhs, rhs in
            itemSortRank(lhs) < itemSortRank(rhs)
        }
    }

    private func itemSortRank(_ item: HomeAdventureItem) -> Int {
        if wallet.canUnlock(item) {
            return 0
        }
        if item.isUnlocked && !wallet.owns(item) {
            return 1
        }
        if wallet.owns(item) {
            return 2
        }
        return 3
    }

    private func unlock(_ item: HomeAdventureItem) {
        let currentWallet = wallet
        guard currentWallet.canUnlock(item) else { return }

        var ids = ownedItemIDs
        ids.insert(item.id)
        ownedItemIDsRaw = HomeAdventureOwnedItemIDs.encode(ids)
    }

    private func unlock(_ world: HomeAdventureWorld) {
        let currentWallet = wallet
        guard currentWallet.canUnlock(world) else { return }

        var ids = unlockedWorldIDs
        ids.insert(world.id)
        unlockedWorldIDsRaw = HomeAdventureOwnedItemIDs.encode(ids)
    }

    private func unlock(_ stage: HomeAdventureStage) {
        let currentWallet = wallet
        guard currentWallet.canUnlock(stage) else { return }

        var ids = unlockedStageIDs
        ids.insert(stage.id)
        unlockedStageIDsRaw = HomeAdventureOwnedItemIDs.encode(ids)
    }

    private var adventureBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.green.opacity(0.08),
                Color.blue.opacity(0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HomeAdventureWorldSection: View {
    let world: HomeAdventureWorld
    let progression: HomeAdventureProgression
    let wallet: HomeAdventureWallet
    let onUnlockWorld: () -> Void
    let onUnlockStage: (HomeAdventureStage) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.black.opacity(isWorldUnlocked ? 0.36 : 0.72),
                    Color.black.opacity(isWorldUnlocked ? 0.1 : 0.52),
                    Color.black.opacity(isWorldUnlocked ? 0.48 : 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HomeAdventureWorldHeader(
                world: world,
                accent: accent,
                creatureSheetAssetName: creatureSheetAssetName,
                isWorldUnlocked: isWorldUnlocked,
                unlockedStageCount: unlockedStageCount,
                canUnlockWorld: wallet.canUnlock(world),
                unlockGuidance: wallet.unlockGuidance(for: world),
                onUnlock: onUnlockWorld
            )

            HomeAdventureWorldEncounterField(
                stages: displayedStages,
                accent: accent,
                creatureSheetAssetName: creatureSheetAssetName,
                progression: progression,
                wallet: wallet,
                onUnlockStage: onUnlockStage
            )
                .padding(.horizontal, 18)
                .padding(.top, 88)
                .padding(.bottom, 18)
        }
        .frame(minHeight: 392)
        .background {
            HomeAdventureWorldArt(assetName: world.artAssetName, isUnlocked: isWorldUnlocked)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(borderOpacity), lineWidth: 1)
        }
    }

    private var isWorldUnlocked: Bool {
        wallet.isWorldUnlocked(world)
    }

    private var unlockedStageCount: Int {
        world.stages.filter { wallet.isStageUnlocked($0) }.count
    }

    private var displayedStages: [HomeAdventureStage] {
        world.stages.map { stage in
            var displayStage = stage
            if wallet.isStageUnlocked(stage) {
                displayStage.status = .cleared
            } else if wallet.canUnlock(stage) {
                displayStage.status = .available
            } else {
                displayStage.status = .locked
            }
            return displayStage
        }
    }

    private var borderOpacity: Double {
        if isWorldUnlocked {
            return 0.42
        }
        if wallet.canUnlock(world) {
            return 0.58
        }
        return 0.22
    }

    private var accent: Color {
        Color.homeAdventureAccent(named: world.accentName)
    }

    private var creatureSheetAssetName: String {
        "\(world.artAssetName)Creatures"
    }
}

private struct HomeAdventureWorldHeader: View {
    let world: HomeAdventureWorld
    let accent: Color
    let creatureSheetAssetName: String
    let isWorldUnlocked: Bool
    let unlockedStageCount: Int
    let canUnlockWorld: Bool
    let unlockGuidance: String
    let onUnlock: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HomeAdventureWorldMedallion(
                creatureSheetAssetName: creatureSheetAssetName,
                isUnlocked: isWorldUnlocked,
                size: 54
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(world.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                    Label(statusTitle, systemImage: statusIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                }

                Text(world.subtitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.44))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(unlockedStageCount)/\(world.stages.count)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("creatures")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                if !isWorldUnlocked {
                    if canUnlockWorld {
                        Button {
                            onUnlock()
                        } label: {
                            Label(world.unlockCost == 0 ? "Choose World" : "\(world.unlockCost.formatted()) coins", systemImage: "lock.open.fill")
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                    } else {
                        Label(unlockGuidance, systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .labelStyle(.titleAndIcon)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .frame(maxWidth: 154, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .padding(16)
    }

    private var statusTitle: String {
        if isWorldUnlocked {
            return "Chosen"
        }
        if canUnlockWorld {
            return "Ready"
        }
        return "Locked"
    }

    private var statusIcon: String {
        if isWorldUnlocked {
            return "checkmark.seal.fill"
        }
        if canUnlockWorld {
            return "sparkles"
        }
        return "lock.fill"
    }

    private var statusTint: Color {
        if isWorldUnlocked {
            return .mint
        }
        if canUnlockWorld {
            return accent
        }
        return .white.opacity(0.72)
    }
}

private struct HomeAdventureWorldMedallion: View {
    let creatureSheetAssetName: String
    let isUnlocked: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(isUnlocked ? 0.28 : 0.44))

            HomeAdventureStageCreatureCrop(
                assetName: creatureSheetAssetName,
                index: 0,
                status: isUnlocked ? .cleared : .locked,
                zoom: 1.14
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(isUnlocked ? 0.05 : 0.36),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.black.opacity(0.42), lineWidth: max(3, size * 0.07))
        }
        .overlay {
            Circle()
                .inset(by: max(2, size * 0.05))
                .strokeBorder(Color.white.opacity(isUnlocked ? 0.74 : 0.34), lineWidth: 1.6)
        }
        .shadow(color: Color.black.opacity(0.32), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

private struct HomeAdventureGuideStrip: View {
    let wallet: HomeAdventureWallet

    var body: some View {
        HStack(spacing: 10) {
            HomeAdventureGuideCard(
                title: "Chosen now",
                value: chosenText,
                detail: chosenDetail,
                systemImage: "location.fill",
                tint: .yellow
            )

            HomeAdventureGuideCard(
                title: "Ready choices",
                value: readyChoiceText,
                detail: readyChoiceDetail,
                systemImage: "lock.open.fill",
                tint: .orange
            )

            HomeAdventureGuideCard(
                title: "Spendable coins",
                value: "\(wallet.spendableCoins.formatted()) coins",
                detail: "Spend them on any ready world, creature, or item.",
                systemImage: "wand.and.stars",
                tint: .green
            )

            HomeAdventureGuideCard(
                title: "Creature stars",
                value: "Coins + actions + days",
                detail: "Stars make a creature ready; clicking unlocks it.",
                systemImage: "star.fill",
                tint: .purple
            )
        }
    }

    private var chosenText: String {
        if let stage = wallet.unlockedStages.last {
            return "Creature \(stage.number): \(stage.title)"
        }
        if let world = wallet.unlockedWorlds.last {
            return world.title
        }
        return "Nothing chosen yet"
    }

    private var chosenDetail: String {
        if let stage = wallet.unlockedStages.last {
            return "\(stage.stars)/3 stars earned and unlocked."
        }
        if wallet.unlockedWorlds.last != nil {
            return "Pick any ready creature in this world."
        }
        return "Start by choosing an eligible world."
    }

    private var readyChoiceText: String {
        let choices = [
            choiceCountText(wallet.purchasableWorlds.count, singular: "world", plural: "worlds"),
            choiceCountText(wallet.purchasableStages.count, singular: "creature", plural: "creatures"),
            choiceCountText(wallet.purchasableItems.count, singular: "item", plural: "items")
        ].compactMap(\.self)

        return choices.isEmpty ? "Earn more progress" : choices.joined(separator: " + ")
    }

    private var readyChoiceDetail: String {
        let readyChoiceCount = wallet.purchasableWorlds.count
            + wallet.purchasableStages.count
            + wallet.purchasableItems.count

        if readyChoiceCount > 0 {
            return "Pick any highlighted choice. Order is yours."
        }
        return "Earn coins, actions, and active days to make choices ready."
    }

    private func choiceCountText(_ count: Int, singular: String, plural: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count) ready \(count == 1 ? singular : plural)"
    }
}

private struct HomeAdventureGuideCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAdventureUnlockGuidance {
    let stage: HomeAdventureStage
    let progression: HomeAdventureProgression

    var missingRequirements: [String] {
        var missing: [String] = []
        if coinGap > 0 {
            missing.append("\(coinGap.formatted()) more coins")
        }
        if actionGap > 0 {
            missing.append("\(actionGap.formatted()) more actions")
        }
        if activeDayGap > 0 {
            missing.append("\(activeDayGap.formatted()) more active days")
        }
        return missing
    }

    var shortSummary: String {
        if coinGap > 0 {
            return "Need \(coinGap.formatted()) more coins"
        }
        if actionGap > 0 {
            return "Need \(actionGap.formatted()) more actions"
        }
        if activeDayGap > 0 {
            return "Need \(activeDayGap.formatted()) more days"
        }
        return "Ready to unlock"
    }

    var summary: String {
        if coinGap > 0 {
            return "Earn \(coinGap.formatted()) coins: \(coinExampleText)."
        }
        if actionGap > 0 {
            return "Do \(actionGap.formatted()) more Routina actions: complete/create tasks, focus, capture notes, log goals, or check in."
        }
        if activeDayGap > 0 {
            return "Use Routina on \(activeDayGap.formatted()) more active days."
        }
        return "Ready: choose this creature whenever you want."
    }

    var coinGap: Int {
        max(0, stage.requiredCoins - progression.totalCoins)
    }

    var actionGap: Int {
        max(0, stage.requiredActions - progression.actionCount)
    }

    var activeDayGap: Int {
        max(0, stage.requiredActiveDays - progression.activeDayCount)
    }

    private var coinExampleText: String {
        let taskCount = requiredCount(forCoinsPerAction: 12)
        let focusCount = requiredCount(forCoinsPerAction: 4)
        let noteCount = requiredCount(forCoinsPerAction: 6)
        return "complete \(taskCount) task\(taskCount == 1 ? "" : "s"), log \(focusCount) focus block\(focusCount == 1 ? "" : "s"), or capture \(noteCount) note/event/emotion action\(noteCount == 1 ? "" : "s")"
    }

    private func requiredCount(forCoinsPerAction coins: Int) -> Int {
        max(1, Int(ceil(Double(coinGap) / Double(coins))))
    }
}

private enum HomeAdventureStagePinRole: Equatable {
    case current
    case next
    case regular

    var compactBadgeTitle: String? {
        switch self {
        case .current:
            return "OWNED"
        case .next:
            return "READY"
        case .regular:
            return nil
        }
    }

    var badgeTint: Color {
        switch self {
        case .current:
            return .mint
        case .next:
            return .orange
        case .regular:
            return .secondary
        }
    }

    var isHighlighted: Bool {
        self != .regular
    }
}

private struct HomeAdventureWorldEncounterField: View {
    let stages: [HomeAdventureStage]
    let accent: Color
    let creatureSheetAssetName: String
    let progression: HomeAdventureProgression
    let wallet: HomeAdventureWallet
    let onUnlockStage: (HomeAdventureStage) -> Void

    private let positions = [
        CGPoint(x: 0.12, y: 0.76),
        CGPoint(x: 0.34, y: 0.58),
        CGPoint(x: 0.22, y: 0.36),
        CGPoint(x: 0.54, y: 0.28),
        CGPoint(x: 0.42, y: 0.12),
        CGPoint(x: 0.8, y: 0.22)
    ]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HomeAdventureStagePin(
                    stage: stage,
                    accent: accent,
                    creatureSheetAssetName: creatureSheetAssetName,
                    creatureIndex: index,
                    progression: progression,
                    wallet: wallet,
                    role: pinRole(for: stage),
                    onUnlock: { onUnlockStage(stage) }
                )
                .position(encounterPoint(at: index, in: geometry.size))
            }
        }
        .frame(height: 280)
    }

    private func encounterPoint(at index: Int, in size: CGSize) -> CGPoint {
        let position = encounterFocus(at: index)
        return CGPoint(
            x: position.x * size.width,
            y: position.y * size.height
        )
    }

    private func encounterFocus(at index: Int) -> CGPoint {
        positions[index % positions.count]
    }

    private func pinRole(for stage: HomeAdventureStage) -> HomeAdventureStagePinRole {
        if stage.id == lastUnlockedStageID {
            return .current
        }
        if wallet.canUnlock(stage) {
            return .next
        }
        return .regular
    }

    private var lastUnlockedStageID: String? {
        stages.last { wallet.isStageUnlocked($0) }?.id
    }
}

private struct HomeAdventureStagePin: View {
    let stage: HomeAdventureStage
    let accent: Color
    let creatureSheetAssetName: String
    let creatureIndex: Int
    let progression: HomeAdventureProgression
    let wallet: HomeAdventureWallet
    let role: HomeAdventureStagePinRole
    let onUnlock: () -> Void
    @State private var isStageDetailPinned = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                toggleStageDetailPin()
            } label: {
                HomeAdventureStageArtwork(
                    stage: stage,
                    accent: accent,
                    creatureSheetAssetName: creatureSheetAssetName,
                    creatureIndex: creatureIndex,
                    role: role
                )
                .frame(width: markerSize, height: markerSize)
            }
            .buttonStyle(.plain)
            .frame(width: markerSize, height: markerSize)
            .contentShape(Circle())
            .help(helpText)
            .accessibilityLabel(accessibilityLabel)
            .popover(isPresented: stageDetailPresentation, arrowEdge: .bottom) {
                HomeAdventureStageDetailPopover(
                    stage: stage,
                    progression: progression,
                    wallet: wallet,
                    guidanceText: wallet.unlockGuidance(for: stage),
                    onUnlock: unlockAndClose
                )
            }

            if let badgeTitle = role.compactBadgeTitle {
                Text(badgeTitle)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(role == .current ? Color.black.opacity(0.82) : Color.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(role.badgeTint, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    }
                    .shadow(color: role.badgeTint.opacity(0.38), radius: 7)
                    .frame(width: markerSize, height: markerSize, alignment: .top)
                    .offset(y: -8)
                    .allowsHitTesting(false)
            }

            Image(systemName: statusIcon)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(statusForeground)
                .frame(width: 26, height: 26)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: statusGlow, radius: 8)
                .allowsHitTesting(false)
        }
        .frame(width: markerHitFrameSize, height: markerHitFrameSize)
    }

    private var markerSize: CGFloat {
        role.isHighlighted ? 78 : 70
    }

    private var markerHitFrameSize: CGFloat {
        role.isHighlighted ? 94 : 86
    }

    private func toggleStageDetailPin() {
        isStageDetailPinned.toggle()
    }

    private func unlockAndClose() {
        onUnlock()
        isStageDetailPinned = false
    }

    private var stageDetailPresentation: Binding<Bool> {
        Binding(
            get: {
                isStageDetailPinned
            },
            set: { isPresented in
                guard !isPresented else { return }
                isStageDetailPinned = false
            }
        )
    }

    private var helpText: String {
        "\(stage.title)\n\(stage.subtitle)\n\(wallet.unlockGuidance(for: stage))\nClick for details and unlock.\n\(stage.requirementText)"
    }

    private var accessibilityLabel: String {
        "Creature \(stage.number), \(stage.title), \(wallet.unlockGuidance(for: stage))"
    }

    private var stageProgressText: String {
        let starText = "\(stage.stars)/3 stars"
        switch stage.status {
        case .locked:
            return "\(starText) | \(wallet.unlockGuidance(for: stage))"
        case .available:
            return "\(starText) | ready to unlock"
        case .cleared:
            return "\(starText) | unlocked"
        }
    }

    private var statusIcon: String {
        switch stage.status {
        case .locked:
            return "lock.fill"
        case .available:
            return "sparkles"
        case .cleared:
            return "checkmark.seal.fill"
        }
    }

    private var statusForeground: Color {
        switch stage.status {
        case .locked:
            return Color.white.opacity(0.58)
        case .available:
            return .yellow
        case .cleared:
            return .mint
        }
    }

    private var statusGlow: Color {
        if role == .current {
            return Color.mint.opacity(0.48)
        }
        if role == .next {
            return Color.orange.opacity(0.52)
        }
        switch stage.status {
        case .locked:
            return Color.black.opacity(0.1)
        case .available:
            return accent.opacity(0.48)
        case .cleared:
            return Color.mint.opacity(0.34)
        }
    }
}

private struct HomeAdventureStageDetailPopover: View {
    let stage: HomeAdventureStage
    let progression: HomeAdventureProgression
    let wallet: HomeAdventureWallet
    let guidanceText: String
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            requirements
            Divider()
            Text(guidanceText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
                .fixedSize(horizontal: false, vertical: true)

            if wallet.isStageUnlocked(stage) {
                Label("Creature unlocked", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Button {
                    onUnlock()
                } label: {
                    Label(wallet.canUnlock(stage) ? "Unlock Creature" : "Locked", systemImage: wallet.canUnlock(stage) ? "lock.open.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(wallet.canUnlock(stage) ? .orange : .secondary)
                .disabled(!wallet.canUnlock(stage))
            }
        }
        .padding(14)
        .frame(width: 286, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Creature \(stage.number)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)

                Text(stageStatusTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusTint.opacity(0.16), in: Capsule())
            }

            Text(stage.title)
                .font(.headline.weight(.semibold))

            Text(stage.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var requirements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(stage.stars)/3 stars")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeAdventureStageRequirementRow(
                title: "Coins",
                systemImage: "circle.hexagongrid.fill",
                tint: .yellow,
                currentValue: progression.totalCoins,
                targetValue: stage.requiredCoins,
                isEarned: stage.coinStarEarned
            )

            HomeAdventureStageRequirementRow(
                title: "Actions",
                systemImage: "bolt.fill",
                tint: .orange,
                currentValue: progression.actionCount,
                targetValue: stage.requiredActions,
                isEarned: stage.actionStarEarned
            )

            HomeAdventureStageRequirementRow(
                title: "Active days",
                systemImage: "calendar",
                tint: .cyan,
                currentValue: progression.activeDayCount,
                targetValue: stage.requiredActiveDays,
                isEarned: stage.activeDayStarEarned
            )
        }
    }

    private var stageStatusTitle: String {
        switch stage.status {
        case .locked:
            return "Locked"
        case .available:
            return "Ready"
        case .cleared:
            return "Unlocked"
        }
    }

    private var statusTint: Color {
        switch stage.status {
        case .locked:
            return .secondary
        case .available:
            return .yellow
        case .cleared:
            return .mint
        }
    }
}

private struct HomeAdventureStageRequirementRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let currentValue: Int
    let targetValue: Int
    let isEarned: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))

                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: isEarned ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(isEarned ? Color.mint : Color.secondary.opacity(0.55))
        }
    }

    private var progressText: String {
        if targetValue <= 0 {
            return "Ready"
        }

        let cappedCurrentValue = min(currentValue, targetValue)
        return "\(cappedCurrentValue.formatted()) / \(targetValue.formatted())"
    }
}

private struct HomeAdventureStageArtwork: View {
    let stage: HomeAdventureStage
    let accent: Color
    let creatureSheetAssetName: String
    let creatureIndex: Int
    let role: HomeAdventureStagePinRole

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                Circle()
                    .fill(Color.black.opacity(stage.status == .locked ? 0.44 : 0.3))

                HomeAdventureStageCreatureCrop(
                    assetName: creatureSheetAssetName,
                    index: creatureIndex,
                    status: stage.status,
                    zoom: 1.16
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(stage.status == .locked ? 0.04 : 0.16),
                        accent.opacity(stage.status == .locked ? 0.08 : 0.18),
                        Color.black.opacity(stage.status == .locked ? 0.46 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(stage.status == .locked ? 0.08 : 0.14))
                    .frame(width: max(16, size.width * 0.28), height: max(16, size.height * 0.28))
                    .offset(x: -size.width * 0.26, y: -size.height * 0.26)
            }
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.black.opacity(stage.status == .locked ? 0.58 : 0.42), lineWidth: role.isHighlighted ? 5 : 4)
        }
        .overlay {
            Circle()
                .inset(by: role.isHighlighted ? 3 : 2.5)
                .strokeBorder(artworkStroke, lineWidth: role.isHighlighted ? 3 : 2)
        }
        .overlay {
            Circle()
                .inset(by: role.isHighlighted ? 7 : 6)
                .strokeBorder(Color.white.opacity(stage.status == .locked ? 0.18 : 0.42), lineWidth: 1)
        }
        .shadow(color: artworkGlow, radius: role.isHighlighted || stage.status == .available ? 18 : 8)
        .saturation(stage.status == .locked ? 0.12 : 1)
        .opacity(stage.status == .locked ? 0.72 : 1)
        .rotationEffect(.degrees(role.isHighlighted ? -3 : 0))
    }

    private var artworkStroke: Color {
        switch role {
        case .current:
            return .yellow
        case .next:
            return .orange
        case .regular:
            return Color.white.opacity(stage.status == .locked ? 0.26 : 0.62)
        }
    }

    private var artworkGlow: Color {
        if role == .current {
            return Color.yellow.opacity(0.42)
        }
        if role == .next {
            return Color.orange.opacity(0.4)
        }
        switch stage.status {
        case .locked:
            return Color.black.opacity(0.12)
        case .available:
            return accent.opacity(0.38)
        case .cleared:
            return Color.mint.opacity(0.25)
        }
    }
}

private struct HomeAdventureStageCreatureCrop: View {
    let assetName: String
    let index: Int
    let status: HomeAdventureStage.Status
    let zoom: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let grid = HomeAdventureCreatureSheetGrid(assetName: assetName)
            let clampedIndex = max(0, min(index, grid.cellCount - 1))
            let column = CGFloat(clampedIndex % grid.columns)
            let row = CGFloat(clampedIndex / grid.columns)
            let cellSize = grid.renderedCellSize(in: size, zoom: zoom)
            let imageWidth = cellSize.width * CGFloat(grid.columns)
            let imageHeight = cellSize.height * CGFloat(grid.rows)

            ZStack {
                Image(assetName)
                    .resizable()
                    .frame(width: imageWidth, height: imageHeight)
                    .offset(
                        x: ((CGFloat(grid.columns) - 1) / 2 - column) * cellSize.width,
                        y: ((CGFloat(grid.rows) - 1) / 2 - row) * cellSize.height
                    )
                    .saturation(status == .locked ? 0.04 : 1.08)
                    .brightness(status == .locked ? -0.2 : 0.02)
                    .contrast(status == .locked ? 0.78 : 1.1)
                    .accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height)
        }
        .clipped()
    }
}

private struct HomeAdventureCreatureSheetGrid {
    let assetName: String
    let columns = 3
    let rows = 2

    var cellCount: Int {
        columns * rows
    }

    var cellAspectRatio: CGFloat {
        let size = pixelSize
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)
        return cellWidth / cellHeight
    }

    func renderedCellSize(in viewport: CGSize, zoom: CGFloat) -> CGSize {
        let width = max(viewport.width, 1)
        let height = max(viewport.height, 1)
        let viewportAspectRatio = width / height
        let safeZoom = max(1, zoom)

        if cellAspectRatio >= viewportAspectRatio {
            let renderedHeight = height * safeZoom
            return CGSize(width: renderedHeight * cellAspectRatio, height: renderedHeight)
        } else {
            let renderedWidth = width * safeZoom
            return CGSize(width: renderedWidth, height: renderedWidth / cellAspectRatio)
        }
    }

    private var pixelSize: CGSize {
        switch assetName {
        case "AdventureClockworkCityCreatures":
            return CGSize(width: 1581, height: 995)
        case "AdventureLunarArchiveCreatures":
            return CGSize(width: 1636, height: 961)
        default:
            return CGSize(width: 1536, height: 1024)
        }
    }
}

private struct HomeAdventureItemCard: View {
    let item: HomeAdventureItem
    let wallet: HomeAdventureWallet
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                HomeAdventureItemArtwork(item: item, isOwned: isOwned, isAvailable: isOwned || canUnlock)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Text(item.kind.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(kindTint)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(kindTint.opacity(0.14), in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                Image(systemName: statusIcon)
                    .foregroundStyle(statusTint)
                    .frame(width: 18, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(wallet.unlockGuidance(for: item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint)
            }

            HStack(spacing: 8) {
                Label(item.requiredCoins.formatted(), systemImage: "circle.hexagongrid.fill")
                Label("\(item.requiredStageCount)", systemImage: "flag.checkered")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if isOwned {
                Label("Owned", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Button {
                    onUnlock()
                } label: {
                    Label(canUnlock ? "Unlock" : "Locked", systemImage: canUnlock ? "lock.open.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(canUnlock ? .orange : .secondary)
                .disabled(!canUnlock)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderTint, lineWidth: 1)
        }
    }

    private var isOwned: Bool {
        wallet.owns(item)
    }

    private var canUnlock: Bool {
        wallet.canUnlock(item)
    }

    private var statusIcon: String {
        if isOwned {
            return "checkmark.seal.fill"
        }
        if canUnlock {
            return "sparkles"
        }
        return "lock.fill"
    }

    private var statusTint: Color {
        if isOwned {
            return .mint
        }
        if canUnlock {
            return .orange
        }
        return .secondary
    }

    private var kindTint: Color {
        switch item.kind {
        case .tool:
            return .cyan
        case .companion:
            return .green
        case .artifact:
            return .purple
        case .booster:
            return .orange
        }
    }

    private var borderTint: Color {
        if canUnlock {
            return Color.orange.opacity(0.45)
        }
        if isOwned {
            return Color.mint.opacity(0.38)
        }
        return Color.white.opacity(0.08)
    }
}

private struct HomeAdventureItemArtwork: View {
    let item: HomeAdventureItem
    let isOwned: Bool
    let isAvailable: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 26, height: 26)
                .offset(x: -14, y: -14)

            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: 44, height: 10)
                .rotationEffect(.degrees(-32))
                .offset(x: 12, y: 15)

            Image(systemName: item.systemImage)
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(isAvailable ? Color.white : Color.secondary)
                .shadow(color: Color.black.opacity(0.22), radius: 2, y: 1)
        }
        .saturation(isAvailable ? 1 : 0.12)
        .opacity(isAvailable ? 1 : 0.7)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isOwned ? Color.mint.opacity(0.72) : Color.white.opacity(0.16), lineWidth: isOwned ? 2 : 1)
        }
    }

    private var palette: [Color] {
        if !isAvailable {
            return [Color.secondary.opacity(0.16), Color.black.opacity(0.22)]
        }

        switch item.kind {
        case .tool:
            return [.cyan, .blue]
        case .companion:
            return [.green, .yellow.opacity(0.82)]
        case .artifact:
            return [.purple, .pink]
        case .booster:
            return [.orange, .red]
        }
    }
}

private struct HomeAdventureMetricTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(.white)
    }
}

private struct HomeAdventureWorldArt: View {
    let assetName: String
    let isUnlocked: Bool

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .saturation(isUnlocked ? 1 : 0.08)
            .brightness(isUnlocked ? -0.04 : -0.22)
            .contrast(isUnlocked ? 1.04 : 0.78)
            .accessibilityHidden(true)
    }
}

private struct HomeAdventureSidebarMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAdventureSidebarWorldCard: View {
    let title: String
    let world: HomeAdventureWorld
    let wallet: HomeAdventureWallet
    let readyCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: "lock.open.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(readyTitle)
                .font(.callout.weight(.medium))

            Text(readyDetail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(wallet.canUnlock(world) ? Color.orange : Color.secondary)

            Text(readyFootnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var readyTitle: String {
        readyCount > 1 ? "\(readyCount) worlds ready" : world.title
    }

    private var readyDetail: String {
        readyCount > 1 ? "Choose any highlighted world card." : wallet.unlockGuidance(for: world)
    }

    private var readyFootnote: String {
        if readyCount > 1 {
            return "Costs use spendable coins."
        }
        return "\(world.unlockCost.formatted()) coins | \(world.stages.count) creatures"
    }
}

private struct HomeAdventureSidebarStageCard: View {
    let title: String
    let stage: HomeAdventureStage
    let wallet: HomeAdventureWallet
    let readyCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(readyTitle)
                .font(.callout.weight(.medium))

            Text(readyDetail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(wallet.canUnlock(stage) ? Color.orange : Color.secondary)

            Text(readyFootnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var readyTitle: String {
        readyCount > 1 ? "\(readyCount) creatures ready" : stage.title
    }

    private var readyDetail: String {
        readyCount > 1 ? "Unlock any glowing creature." : wallet.unlockGuidance(for: stage)
    }

    private var readyFootnote: String {
        readyCount > 1 ? "No creature order is required." : stage.requirementText
    }
}

private struct HomeAdventureSidebarItemCard: View {
    let item: HomeAdventureItem
    let wallet: HomeAdventureWallet
    let readyCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(.orange)
                    .frame(width: 18)
                Text(readyCount == 1 ? "Ready Item" : "Ready Items")
                    .font(.subheadline.weight(.semibold))
            }

            Text(readyTitle)
                .font(.callout.weight(.medium))

            Text(readyCostText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Unlock now, or save coins for a rarer companion or artifact.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var readyTitle: String {
        readyCount > 1 ? "\(readyCount) items ready" : item.title
    }

    private var readyCostText: String {
        readyCount > 1
            ? "\(wallet.spendableCoins.formatted()) spendable coins"
            : "\(item.requiredCoins.formatted()) coins | \(wallet.spendableCoins.formatted()) spendable"
    }
}

private struct HomeAdventureSidebarUnlockCard: View {
    let stage: HomeAdventureStage
    let progression: HomeAdventureProgression

    private var guidance: HomeAdventureUnlockGuidance {
        HomeAdventureUnlockGuidance(stage: stage, progression: progression)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Unlock Goal")
                    .font(.subheadline.weight(.semibold))
                Text("Stage \(stage.number): \(stage.title)")
                    .font(.callout.weight(.medium))
                Label(guidance.shortSummary, systemImage: "lock.open.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                HomeAdventureRequirementProgressRow(
                    title: "Coins",
                    currentValue: progression.totalCoins,
                    targetValue: stage.requiredCoins,
                    gapValue: guidance.coinGap,
                    unit: "coins",
                    systemImage: "circle.hexagongrid.fill",
                    tint: .yellow
                )
                HomeAdventureRequirementProgressRow(
                    title: "Actions",
                    currentValue: progression.actionCount,
                    targetValue: stage.requiredActions,
                    gapValue: guidance.actionGap,
                    unit: "actions",
                    systemImage: "bolt.fill",
                    tint: .orange
                )
                HomeAdventureRequirementProgressRow(
                    title: "Active days",
                    currentValue: progression.activeDayCount,
                    targetValue: stage.requiredActiveDays,
                    gapValue: guidance.activeDayGap,
                    unit: "days",
                    systemImage: "calendar",
                    tint: .cyan
                )
            }

            Text(guidance.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAdventureRequirementProgressRow: View {
    let title: String
    let currentValue: Int
    let targetValue: Int
    let gapValue: Int
    let unit: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: gapValue == 0 ? "checkmark.circle.fill" : systemImage)
                    .foregroundStyle(gapValue == 0 ? Color.green : tint)
                    .frame(width: 16)

                Text(title)
                    .font(.caption.weight(.semibold))

                Spacer()

                Text("\(currentValue.formatted())/\(targetValue.formatted())")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(Double(currentValue), Double(targetValue)), total: Double(targetValue))
                .tint(gapValue == 0 ? .green : tint)

            Text(gapText)
                .font(.caption2)
                .foregroundStyle(gapValue == 0 ? Color.green : Color.secondary)
        }
    }

    private var gapText: String {
        if gapValue == 0 {
            return "Requirement met"
        }
        return "Need \(gapValue.formatted()) more \(unit)"
    }
}

private extension Color {
    static func homeAdventureAccent(named name: String) -> Color {
        switch name {
        case "green":
            return .green
        case "blue":
            return .blue
        case "indigo":
            return .indigo
        case "mint":
            return .mint
        case "pink":
            return .pink
        default:
            return .accentColor
        }
    }
}
