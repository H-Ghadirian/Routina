import SwiftUI

struct HomeAdventureSidebarMetric: View {
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

struct HomeAdventureSidebarWorldCard: View {
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

struct HomeAdventureSidebarStageCard: View {
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

struct HomeAdventureSidebarItemCard: View {
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

struct HomeAdventureSidebarUnlockCard: View {
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

struct HomeAdventureRequirementProgressRow: View {
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
