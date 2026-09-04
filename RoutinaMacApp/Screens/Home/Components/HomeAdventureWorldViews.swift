import SwiftUI

struct HomeAdventureWorldSection: View {
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
                    Color.black.opacity(isWorldUnlocked ? 0.48 : 0.78),
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
                            Label(
                                world.unlockCost == 0 ? "Choose World" : "\(world.unlockCost.formatted()) coins",
                                systemImage: "lock.open.fill")
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

struct HomeAdventureWorldMedallion: View {
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
                    Color.black.opacity(0.18),
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

enum HomeAdventureStagePinRole: Equatable {
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
