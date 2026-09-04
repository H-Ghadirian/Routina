import SwiftUI

struct HomeMacAdventureView: View {
    let progression: HomeAdventureProgression
    @State private var selectedScreen = HomeAdventureScreen.map
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue, store: SharedDefaults.app)
    private var isAwayEnabled = false
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
                screenPicker
                selectedScreenContent
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(adventureBackground)
        .navigationTitle("Adventure")
    }

    private var screenPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Adventure screen",
            options: HomeAdventureScreen.allCases,
            selection: $selectedScreen,
            fillsAvailableWidth: true
        ) { screen in
            Text(screen.title)
        }
        .frame(maxWidth: 300, alignment: .leading)
        .accessibilityIdentifier("adventure.screenPicker")
    }

    @ViewBuilder
    private var selectedScreenContent: some View {
        switch selectedScreen {
        case .map:
            mapContent
        case .earnCoins:
            HomeAdventureCoinGuideScreen(
                progression: progression,
                wallet: wallet,
                showsPlaces: isPlacesEnabled,
                showsAway: isAwayEnabled
            )
        }
    }

    private var mapContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HomeAdventureGuideStrip(wallet: wallet)
            worldsSection
            itemsSection
        }
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.56),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.6),
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
                        Text("Earn coins from real repeating-task progress, then choose which companions and artifacts to unlock.")
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
                Color.blue.opacity(0.07),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
