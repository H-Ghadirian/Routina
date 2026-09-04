import SwiftUI

struct HomeAdventureGuideStrip: View {
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
            choiceCountText(wallet.purchasableItems.count, singular: "item", plural: "items"),
        ].compactMap(\.self)

        return choices.isEmpty ? "Earn more progress" : choices.joined(separator: " + ")
    }

    private var readyChoiceDetail: String {
        let readyChoiceCount =
            wallet.purchasableWorlds.count
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

enum HomeAdventureScreen: String, CaseIterable, Identifiable {
    case map
    case earnCoins

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map:
            return "Map"
        case .earnCoins:
            return "Earn Coins"
        }
    }
}

struct HomeAdventureCoinGuideScreen: View {
    let progression: HomeAdventureProgression
    let wallet: HomeAdventureWallet
    let showsPlaces: Bool
    let showsAway: Bool

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 210), spacing: 10)
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 300), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.yellow)
                        .frame(width: 36, height: 36)
                        .background(Color.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to earn coins")
                            .font(.title3.weight(.bold))
                        Text(
                            "Every action below adds to lifetime Adventure coins. "
                                + "Spendable coins are what remain after your chosen world, creature, and item unlocks."
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(wallet.spendableCoins.formatted())
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.yellow)
                        Text("spendable")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 10) {
                    HomeAdventureCoinSummaryPill(
                        title: "Lifetime earned",
                        value: progression.totalCoins.formatted(),
                        systemImage: "banknote.fill",
                        tint: .yellow
                    )
                    HomeAdventureCoinSummaryPill(
                        title: "Chosen unlock costs",
                        value: max(0, progression.totalCoins - wallet.spendableCoins).formatted(),
                        systemImage: "lock.open.fill",
                        tint: .orange
                    )
                    HomeAdventureCoinSummaryPill(
                        title: "Rewarded actions",
                        value: progression.actionCount.formatted(),
                        systemImage: "sparkles",
                        tint: .green
                    )
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(visibleCoinRules) { rule in
                    HomeAdventureCoinRuleCard(
                        rule: rule,
                        source: progression.sources.first { $0.id == rule.id }
                    )
                }
            }
        }
    }

    private var visibleCoinRules: [HomeAdventureCoinRule] {
        HomeAdventureCoinRule.all.filter { rule in
            (showsPlaces || rule.id != "places")
                && (showsAway || rule.id != "away")
        }
    }
}

private struct HomeAdventureCoinSummaryPill: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HomeAdventureCoinRuleCard: View {
    let rule: HomeAdventureCoinRule
    let source: HomeAdventureCoinSource?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rule.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.yellow)
                .frame(width: 34, height: 34)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(rule.actionTitle)
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Each \(rule.unitSingular) gives \(rule.coinsPerAction.formatted()) coins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let source {
                    Text("\(source.countText) so far = \(source.coins.formatted()) coins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            Text("+\(rule.coinsPerAction.formatted())")
                .font(.callout.weight(.heavy))
                .foregroundStyle(.yellow)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.yellow.opacity(0.14), in: Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
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

struct HomeAdventureUnlockGuidance {
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
            return "Do \(actionGap.formatted()) more Routina actions: complete or create tasks, focus, or log goals."
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
        return
            "complete \(taskCount) task\(taskCount == 1 ? "" : "s"), log \(focusCount) focus block\(focusCount == 1 ? "" : "s"), or capture \(noteCount) note/event/emotion action\(noteCount == 1 ? "" : "s")"
    }

    private func requiredCount(forCoinsPerAction coins: Int) -> Int {
        max(1, Int(ceil(Double(coinGap) / Double(coins))))
    }
}
