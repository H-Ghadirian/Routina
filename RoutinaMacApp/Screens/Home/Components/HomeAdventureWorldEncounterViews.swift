import SwiftUI

struct HomeAdventureWorldEncounterField: View {
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
        CGPoint(x: 0.8, y: 0.22),
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

struct HomeAdventureStagePin: View {
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
