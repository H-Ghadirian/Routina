import SwiftUI

struct HomeAdventureItemCard: View {
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

struct HomeAdventureMetricTile: View {
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

struct HomeAdventureWorldArt: View {
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
