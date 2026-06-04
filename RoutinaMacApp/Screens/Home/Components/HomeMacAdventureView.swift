import SwiftUI

struct HomeMacAdventureSidebarView: View {
    let progression: HomeAdventureProgression
    @AppStorage(UserDefaultStringValueKey.appSettingMacAdventureOwnedItemIDs.rawValue, store: SharedDefaults.app)
    private var ownedItemIDsRaw = ""

    private var wallet: HomeAdventureWallet {
        HomeAdventureWallet(
            totalCoins: progression.totalCoins,
            completedStageCount: progression.completedStageCount,
            items: progression.items,
            ownedItemIDs: HomeAdventureOwnedItemIDs.decode(ownedItemIDsRaw)
        )
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
                            title: "Owned",
                            value: "\(wallet.ownedItemCount)",
                            systemImage: "backpack.fill"
                        )
                    }

                    HStack(spacing: 8) {
                        HomeAdventureSidebarMetric(
                            title: "Level",
                            value: "\(progression.level)",
                            systemImage: "sparkles"
                        )
                        HomeAdventureSidebarMetric(
                            title: "Stages",
                            value: "\(progression.completedStageCount)",
                            systemImage: "flag.checkered"
                        )
                    }

                    ProgressView(value: progression.levelProgress)
                        .tint(.yellow)
                    Text("\(progression.totalXP.formatted()) XP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let stage = progression.currentStage {
                    HomeAdventureSidebarStageCard(title: "You Are Here", stage: stage)
                }

                if let item = wallet.firstPurchasableItem {
                    HomeAdventureSidebarItemCard(item: item, wallet: wallet)
                }

                if let stage = progression.nextLockedStage {
                    HomeAdventureSidebarUnlockCard(stage: stage, progression: progression)
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

    private let itemColumns = [
        GridItem(.adaptive(minimum: 180), spacing: 12)
    ]

    private var ownedItemIDs: Set<String> {
        HomeAdventureOwnedItemIDs.decode(ownedItemIDsRaw)
    }

    private var wallet: HomeAdventureWallet {
        HomeAdventureWallet(
            totalCoins: progression.totalCoins,
            completedStageCount: progression.completedStageCount,
            items: progression.items,
            ownedItemIDs: ownedItemIDs
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                HomeAdventureGuideStrip(progression: progression, wallet: wallet)
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
                            isUnlocked: true,
                            size: 58
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adventure Map")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Earn coins from real routine progress, then choose which companions and artifacts to unlock.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.82))
                        if let world = progression.currentWorld {
                            Text("Current world: \(world.title)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    HomeAdventureMetricTile(title: "Spendable", value: wallet.spendableCoins.formatted(), systemImage: "circle.hexagongrid.fill", tint: .yellow)
                    HomeAdventureMetricTile(title: "Level", value: "\(progression.level)", systemImage: "sparkles", tint: .purple)
                    HomeAdventureMetricTile(title: "Stages", value: "\(progression.completedStageCount)/\(progression.worlds.flatMap(\.stages).count)", systemImage: "flag.checkered", tint: .green)
                    HomeAdventureMetricTile(title: "Owned", value: "\(wallet.ownedItemCount)/\(progression.items.count)", systemImage: "backpack.fill", tint: .orange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Level \(progression.level) progress")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("\(Int((progression.levelProgress * 100).rounded()))%")
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
                HomeAdventureWorldArt(assetName: world.artAssetName, isUnlocked: true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var heroWorld: HomeAdventureWorld? {
        progression.currentWorld ?? progression.worlds.first
    }

    private var worldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Worlds")
                .font(.title3.weight(.bold))

            ForEach(progression.worlds) { world in
                HomeAdventureWorldSection(
                    world: world,
                    progression: progression,
                    currentStageID: progression.currentStage?.id,
                    nextLockedStageID: progression.nextLockedStage?.id
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
    let currentStageID: String?
    let nextLockedStageID: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.black.opacity(world.isUnlocked ? 0.36 : 0.72),
                    Color.black.opacity(world.isUnlocked ? 0.1 : 0.52),
                    Color.black.opacity(world.isUnlocked ? 0.48 : 0.76)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HomeAdventureWorldHeader(
                world: world,
                accent: accent,
                creatureSheetAssetName: creatureSheetAssetName
            )

            HomeAdventureWorldEncounterField(
                stages: world.stages,
                accent: accent,
                creatureSheetAssetName: creatureSheetAssetName,
                progression: progression,
                currentStageID: currentStageID,
                nextLockedStageID: nextLockedStageID
            )
                .padding(.horizontal, 18)
                .padding(.top, 88)
                .padding(.bottom, 18)
        }
        .frame(minHeight: 392)
        .background {
            HomeAdventureWorldArt(assetName: world.artAssetName, isUnlocked: world.isUnlocked)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(world.isUnlocked ? 0.42 : 0.22), lineWidth: 1)
        }
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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HomeAdventureWorldMedallion(
                creatureSheetAssetName: creatureSheetAssetName,
                isUnlocked: world.isUnlocked,
                size: 54
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(world.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

                    Text(world.isUnlocked ? "Open" : "Locked")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(world.isUnlocked ? .mint : .white.opacity(0.78))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.38), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        }
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

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(world.clearedStageCount)/\(world.stages.count)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("cleared")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
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
                status: isUnlocked ? .cleared : .locked
            )
            .padding(max(4, size * 0.08))

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
                .strokeBorder(Color.white.opacity(isUnlocked ? 0.7 : 0.34), lineWidth: 2)
        }
        .shadow(color: Color.black.opacity(0.32), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

private struct HomeAdventureGuideStrip: View {
    let progression: HomeAdventureProgression
    let wallet: HomeAdventureWallet

    var body: some View {
        HStack(spacing: 10) {
            HomeAdventureGuideCard(
                title: "You are here",
                value: currentStageText,
                detail: currentStageDetail,
                systemImage: "location.fill",
                tint: .yellow
            )

            HomeAdventureGuideCard(
                title: "Do this next",
                value: nextStageText,
                detail: nextActionDetail,
                systemImage: "lock.open.fill",
                tint: .orange
            )

            HomeAdventureGuideCard(
                title: "Choose unlock",
                value: unlockChoiceText,
                detail: unlockChoiceDetail,
                systemImage: "wand.and.stars",
                tint: .green
            )

            HomeAdventureGuideCard(
                title: "Stage stars",
                value: "Coins + actions + days",
                detail: "Each star is one met requirement.",
                systemImage: "star.fill",
                tint: .purple
            )
        }
    }

    private var currentStageText: String {
        guard let stage = progression.currentStage else { return "Before Stage 1" }
        return "Stage \(stage.number): \(stage.title)"
    }

    private var currentStageDetail: String {
        guard let stage = progression.currentStage else { return "Earn coins to open the first encounter." }
        switch stage.status {
        case .locked:
            return "Earn coins to open this gate."
        case .available:
            return "\(stage.stars)/3 stars earned."
        case .cleared:
            return "Last cleared stage."
        }
    }

    private var nextStageText: String {
        guard let stage = progression.nextLockedStage else { return "Season complete" }
        return "Stage \(stage.number): \(stage.title)"
    }

    private var nextStageDetail: String {
        guard let stage = progression.nextLockedStage else { return "All Adventure stages are cleared." }
        let missing = missingRequirements(for: stage)
        guard !missing.isEmpty else { return "Ready now." }
        return "Need \(missing.joined(separator: ", "))."
    }

    private var nextActionDetail: String {
        guard let stage = progression.nextLockedStage else { return "All Adventure stages are cleared." }
        return HomeAdventureUnlockGuidance(stage: stage, progression: progression).summary
    }

    private var unlockChoiceText: String {
        guard let item = wallet.firstPurchasableItem else {
            return "\(wallet.spendableCoins.formatted()) spendable coins"
        }
        return item.title
    }

    private var unlockChoiceDetail: String {
        guard let item = wallet.firstPurchasableItem else {
            return "Earn progress or save coins for the next item choice."
        }
        return "\(item.requiredCoins.formatted()) coins | \(item.kind.title)"
    }

    private func missingRequirements(for stage: HomeAdventureStage) -> [String] {
        HomeAdventureUnlockGuidance(stage: stage, progression: progression).missingRequirements
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
        return "Ready: the next encounter is open."
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

    var badgeTitle: String? {
        switch self {
        case .current:
            return "YOU ARE HERE"
        case .next:
            return "NEXT UNLOCK"
        case .regular:
            return nil
        }
    }

    var badgeTint: Color {
        switch self {
        case .current:
            return .yellow
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
    let currentStageID: String?
    let nextLockedStageID: String?

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
                    role: pinRole(for: stage),
                    unlockGuidance: unlockGuidance(for: stage)
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
        if stage.id == currentStageID {
            return .current
        }
        if stage.id == nextLockedStageID {
            return .next
        }
        return .regular
    }

    private func unlockGuidance(for stage: HomeAdventureStage) -> String? {
        guard stage.id == nextLockedStageID else { return nil }
        return HomeAdventureUnlockGuidance(stage: stage, progression: progression).shortSummary
    }
}

private struct HomeAdventureStagePin: View {
    let stage: HomeAdventureStage
    let accent: Color
    let creatureSheetAssetName: String
    let creatureIndex: Int
    let role: HomeAdventureStagePinRole
    let unlockGuidance: String?

    var body: some View {
        VStack(spacing: 5) {
            if let badgeTitle = role.badgeTitle {
                Text(badgeTitle)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(role == .current ? Color.black : Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(role.badgeTint, in: Capsule())
                    .shadow(color: role.badgeTint.opacity(0.35), radius: 8)
            }

            ZStack(alignment: .bottomTrailing) {
                HomeAdventureStageArtwork(
                    stage: stage,
                    accent: accent,
                    creatureSheetAssetName: creatureSheetAssetName,
                    creatureIndex: creatureIndex,
                    role: role
                )
                    .frame(width: role.isHighlighted ? 74 : 66, height: role.isHighlighted ? 74 : 66)

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
            }

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text("\(stage.number)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(stage.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HomeAdventureStageRequirementMarks(stage: stage)
                }

                Text(unlockGuidance ?? stageProgressText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: 156)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(plateFill)
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
        .frame(width: 168, height: 132)
        .help("\(stage.subtitle)\n\(stage.requirementText)")
    }

    private var stageProgressText: String {
        let starText = "\(stage.stars)/3 stars"
        switch stage.status {
        case .locked:
            return "\(starText) | \(stage.requiredCoins.formatted()) coins"
        case .available:
            return "\(starText) | finish requirements"
        case .cleared:
            return "\(starText) | cleared"
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

    private var plateFill: Color {
        switch stage.status {
        case .locked:
            return Color.black.opacity(0.18)
        case .available:
            return accent.opacity(0.22)
        case .cleared:
            return Color.green.opacity(0.2)
        }
    }

    private var statusGlow: Color {
        if role == .current {
            return Color.yellow.opacity(0.55)
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
                    status: stage.status
                )
                .padding(stage.status == .locked ? 6 : 5)

                LinearGradient(
                    colors: [
                        Color.black.opacity(stage.status == .locked ? 0.5 : 0.18),
                        accent.opacity(stage.status == .locked ? 0.12 : 0.2),
                        Color.black.opacity(0.32)
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
                .stroke(artworkStroke, lineWidth: role.isHighlighted ? 3 : 1.5)
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

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let columns: CGFloat = 3
            let rows: CGFloat = 2
            let clampedIndex = max(0, min(index, 5))
            let column = CGFloat(clampedIndex % Int(columns))
            let row = CGFloat(clampedIndex / Int(columns))
            let imageWidth = size.width * columns
            let imageHeight = size.height * rows

            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: imageHeight)
                    .offset(
                        x: ((columns - 1) / 2 - column) * size.width,
                        y: ((rows - 1) / 2 - row) * size.height
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

private struct HomeAdventureStageRequirementMarks: View {
    let stage: HomeAdventureStage

    var body: some View {
        HStack(spacing: 2) {
            requirementMark(systemImage: "circle.hexagongrid.fill", isEarned: stage.coinStarEarned, tint: .yellow)
            requirementMark(systemImage: "bolt.fill", isEarned: stage.actionStarEarned, tint: .orange)
            requirementMark(systemImage: "calendar", isEarned: stage.activeDayStarEarned, tint: .cyan)
        }
    }

    private func requirementMark(systemImage: String, isEarned: Bool, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(isEarned ? tint : Color.white.opacity(0.32))
            .frame(width: 10, height: 10)
    }
}

private struct HomeAdventureItemCard: View {
    let item: HomeAdventureItem
    let wallet: HomeAdventureWallet
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                HomeAdventureItemArtwork(item: item, isOwned: isOwned, isAvailable: item.isUnlocked)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                    Text(item.kind.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(kindTint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(kindTint.opacity(0.14), in: Capsule())
                }

                Spacer(minLength: 4)

                Image(systemName: statusIcon)
                    .foregroundStyle(statusTint)
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
        if item.isUnlocked {
            return .yellow
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
                    .foregroundStyle(.secondary)
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

private struct HomeAdventureSidebarStageCard: View {
    let title: String
    let stage: HomeAdventureStage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(stage.title)
                .font(.callout.weight(.medium))
            Text(stage.requirementText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAdventureSidebarItemCard: View {
    let item: HomeAdventureItem
    let wallet: HomeAdventureWallet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(.orange)
                    .frame(width: 18)
                Text("Ready Item")
                    .font(.subheadline.weight(.semibold))
            }

            Text(item.title)
                .font(.callout.weight(.medium))

            Text("\(item.requiredCoins.formatted()) coins | \(wallet.spendableCoins.formatted()) spendable")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Claim now, or save coins for a rarer companion or artifact.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                Text("Next Unlock")
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
