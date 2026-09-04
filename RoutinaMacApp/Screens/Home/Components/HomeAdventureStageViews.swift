import SwiftUI

struct HomeAdventureStageDetailPopover: View {
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
            if showsSpendableBudget {
                Divider()
                spendableBudget
            }
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
                    Label(unlockButtonTitle, systemImage: unlockButtonIcon)
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
                title: "Coins earned",
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

    private var spendableBudget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlock price")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HomeAdventureStageRequirementRow(
                title: "Spendable budget",
                systemImage: "circle.hexagongrid.fill",
                tint: .yellow,
                currentValue: wallet.spendableCoins,
                targetValue: stage.unlockCost,
                isEarned: wallet.spendableCoins >= stage.unlockCost
            )
        }
    }

    private var showsSpendableBudget: Bool {
        !wallet.isStageUnlocked(stage)
            && isWorldChosen
            && stage.isEligible
    }

    private var isWorldChosen: Bool {
        wallet.unlockedWorldIDs.contains(stage.worldID)
    }

    private var spendableCoinGap: Int {
        max(0, stage.unlockCost - wallet.spendableCoins)
    }

    private var isEligibleButCannotAfford: Bool {
        showsSpendableBudget && spendableCoinGap > 0
    }

    private var unlockButtonTitle: String {
        if wallet.canUnlock(stage) {
            return "Unlock Creature"
        }
        if isEligibleButCannotAfford {
            return "Need \(spendableCoinGap.formatted()) Spendable"
        }
        return "Locked"
    }

    private var unlockButtonIcon: String {
        wallet.canUnlock(stage) ? "lock.open.fill" : "lock.fill"
    }

    private var stageStatusTitle: String {
        if wallet.isStageUnlocked(stage) {
            return "Unlocked"
        }
        if wallet.canUnlock(stage) {
            return "Ready"
        }
        if isEligibleButCannotAfford {
            return "Need Coins"
        }

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
        if wallet.isStageUnlocked(stage) {
            return .mint
        }
        if wallet.canUnlock(stage) || isEligibleButCannotAfford {
            return .yellow
        }

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

struct HomeAdventureStageArtwork: View {
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
                        Color.black.opacity(stage.status == .locked ? 0.46 : 0.18),
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

struct HomeAdventureStageCreatureCrop: View {
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
