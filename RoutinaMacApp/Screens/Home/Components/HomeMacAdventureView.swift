import SwiftUI

struct HomeMacAdventureSidebarView: View {
    let progression: HomeAdventureProgression

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Adventure", systemImage: "map.fill")
                        .font(.headline)

                    HStack(spacing: 8) {
                        HomeAdventureSidebarMetric(
                            title: "Coins",
                            value: progression.totalCoins.formatted(),
                            systemImage: "circle.hexagongrid.fill"
                        )
                        HomeAdventureSidebarMetric(
                            title: "Level",
                            value: "\(progression.level)",
                            systemImage: "sparkles"
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
                    HomeAdventureSidebarStageCard(title: "Current Stage", stage: stage)
                }

                if let stage = progression.nextLockedStage {
                    HomeAdventureSidebarStageCard(title: "Next Unlock", stage: stage)
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

    private let itemColumns = [
        GridItem(.adaptive(minimum: 180), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                worldsSection
                itemsSection
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
                    Image(systemName: progression.currentWorld?.systemImage ?? "map.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            LinearGradient(
                                colors: [.green, .cyan, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adventure Map")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Clear stages, unlock worlds, and collect artifacts from real routine progress.")
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
                    HomeAdventureMetricTile(title: "Coins", value: progression.totalCoins.formatted(), systemImage: "circle.hexagongrid.fill", tint: .yellow)
                    HomeAdventureMetricTile(title: "Level", value: "\(progression.level)", systemImage: "sparkles", tint: .purple)
                    HomeAdventureMetricTile(title: "Stages", value: "\(progression.completedStageCount)/\(progression.worlds.flatMap(\.stages).count)", systemImage: "flag.checkered", tint: .green)
                    HomeAdventureMetricTile(title: "Items", value: "\(progression.unlockedItemCount)/\(progression.items.count)", systemImage: "backpack.fill", tint: .orange)
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
                HomeAdventureWorldSection(world: world)
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.title3.weight(.bold))

            LazyVGrid(columns: itemColumns, alignment: .leading, spacing: 12) {
                ForEach(progression.items) { item in
                    HomeAdventureItemCard(item: item)
                }
            }
        }
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

            HomeAdventureWorldHeader(world: world, accent: accent)

            HomeAdventureWorldRoute(stages: world.stages, accent: accent)
                .padding(.horizontal, 18)
                .padding(.top, 66)
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
}

private struct HomeAdventureWorldHeader: View {
    let world: HomeAdventureWorld
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: world.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(world.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(world.isUnlocked ? "Open" : "Locked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(world.isUnlocked ? .green : .white.opacity(0.72))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Text(world.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(16)
    }
}

private struct HomeAdventureWorldRoute: View {
    let stages: [HomeAdventureStage]
    let accent: Color

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
            let stagePoints = stages.indices.map { index in
                routePoint(at: index, in: geometry.size)
            }

            Path { path in
                guard let first = stagePoints.first else { return }
                path.move(to: first)
                for point in stagePoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [10, 9]))

            Path { path in
                guard let first = stagePoints.first else { return }
                path.move(to: first)
                for point in stagePoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(accent.opacity(0.48), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HomeAdventureStagePin(stage: stage, accent: accent)
                    .position(stagePoints[index])
            }
        }
        .frame(height: 280)
    }

    private func routePoint(at index: Int, in size: CGSize) -> CGPoint {
        let position = positions[index % positions.count]
        return CGPoint(
            x: position.x * size.width,
            y: position.y * size.height
        )
    }
}

private struct HomeAdventureStagePin: View {
    let stage: HomeAdventureStage
    let accent: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(nodeFill)
                    .shadow(color: nodeGlow, radius: stage.status == .available ? 18 : 8)

                Circle()
                    .strokeBorder(Color.white.opacity(0.78), lineWidth: 2)

                Image(systemName: stageIcon)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(stage.status == .locked ? Color.white.opacity(0.56) : Color.white)
            }
            .frame(width: 58, height: 58)

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text("\(stage.number)")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(stage.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    stars
                }

                Text(stage.status == .locked ? "\(stage.requiredCoins.formatted()) coins" : stageStatusText)
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
                    .fill(nodePlateFill)
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
        .frame(width: 166, height: 110)
        .help("\(stage.subtitle)\n\(stage.requirementText)")
    }

    private var stars: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stage.stars ? "star.fill" : "star")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(index < stage.stars ? Color.yellow : Color.white.opacity(0.35))
            }
        }
    }

    private var stageStatusText: String {
        switch stage.status {
        case .locked:
            return "\(stage.requiredCoins.formatted()) coins"
        case .available:
            return "next route"
        case .cleared:
            return "cleared"
        }
    }

    private var stageIcon: String {
        switch stage.status {
        case .locked:
            return "lock.fill"
        case .available:
            return "play.fill"
        case .cleared:
            return "checkmark"
        }
    }

    private var nodeFill: Color {
        switch stage.status {
        case .locked:
            return Color.black.opacity(0.42)
        case .available:
            return accent
        case .cleared:
            return .green
        }
    }

    private var nodePlateFill: Color {
        switch stage.status {
        case .locked:
            return Color.black.opacity(0.18)
        case .available:
            return accent.opacity(0.22)
        case .cleared:
            return Color.green.opacity(0.2)
        }
    }

    private var nodeGlow: Color {
        switch stage.status {
        case .locked:
            return Color.black.opacity(0.1)
        case .available:
            return accent.opacity(0.48)
        case .cleared:
            return Color.green.opacity(0.34)
        }
    }
}

private struct HomeAdventureItemCard: View {
    let item: HomeAdventureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(item.isUnlocked ? Color.white : Color.secondary)
                    .frame(width: 38, height: 38)
                    .background(item.isUnlocked ? Color.orange : Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Image(systemName: item.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(item.isUnlocked ? Color.green : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("\(item.requiredCoins.formatted()) coins | \(item.requiredStageCount) stages")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
