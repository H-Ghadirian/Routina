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
                    HomeAdventureSidebarStageCard(title: "You Are Here", stage: stage)
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
                HomeAdventureGuideStrip(progression: progression)
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
                HomeAdventureWorldSection(
                    world: world,
                    currentStageID: progression.currentStage?.id,
                    nextLockedStageID: progression.nextLockedStage?.id
                )
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

            HomeAdventureWorldHeader(world: world, accent: accent)

            HomeAdventureWorldRoute(
                stages: world.stages,
                accent: accent,
                currentStageID: currentStageID,
                nextLockedStageID: nextLockedStageID
            )
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

private struct HomeAdventureGuideStrip: View {
    let progression: HomeAdventureProgression

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
                title: "Next unlock",
                value: nextStageText,
                detail: nextStageDetail,
                systemImage: "lock.open.fill",
                tint: .orange
            )

            HomeAdventureGuideCard(
                title: "Path",
                value: "Linear 1 -> 30",
                detail: "Each stage leads to the next numbered stage.",
                systemImage: "arrow.right.circle.fill",
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
        guard let stage = progression.currentStage else { return "Earn coins to open the first route." }
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
        guard !missing.isEmpty else { return "Ready when the path reaches it." }
        return "Need \(missing.joined(separator: ", "))."
    }

    private func missingRequirements(for stage: HomeAdventureStage) -> [String] {
        var missing: [String] = []
        if progression.totalCoins < stage.requiredCoins {
            missing.append("\((stage.requiredCoins - progression.totalCoins).formatted()) coins")
        }
        if progression.actionCount < stage.requiredActions {
            missing.append("\((stage.requiredActions - progression.actionCount).formatted()) actions")
        }
        if progression.activeDayCount < stage.requiredActiveDays {
            missing.append("\((stage.requiredActiveDays - progression.activeDayCount).formatted()) active days")
        }
        return missing
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
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct HomeAdventureWorldRoute: View {
    let stages: [HomeAdventureStage]
    let accent: Color
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
            let stagePoints = stages.indices.map { index in
                routePoint(at: index, in: geometry.size)
            }

            ForEach(Array(stages.indices.dropLast()), id: \.self) { index in
                Path { path in
                    path.move(to: stagePoints[index])
                    path.addLine(to: stagePoints[index + 1])
                }
                .stroke(segmentColor(at: index), style: segmentStroke(at: index))
            }

            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HomeAdventureStagePin(stage: stage, accent: accent, role: pinRole(for: stage))
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

    private func pinRole(for stage: HomeAdventureStage) -> HomeAdventureStagePinRole {
        if stage.id == currentStageID {
            return .current
        }
        if stage.id == nextLockedStageID {
            return .next
        }
        return .regular
    }

    private func segmentColor(at index: Int) -> Color {
        let fromStage = stages[index]
        let toStage = stages[index + 1]
        if fromStage.status == .cleared && toStage.status == .cleared {
            return .green.opacity(0.72)
        }
        if fromStage.status != .locked || toStage.status != .locked {
            return accent.opacity(0.64)
        }
        return Color.white.opacity(0.32)
    }

    private func segmentStroke(at index: Int) -> StrokeStyle {
        let fromStage = stages[index]
        let toStage = stages[index + 1]
        let isCompleted = fromStage.status == .cleared && toStage.status == .cleared
        return StrokeStyle(
            lineWidth: isCompleted ? 5 : 4,
            lineCap: .round,
            lineJoin: .round,
            dash: isCompleted ? [] : [9, 8]
        )
    }
}

private struct HomeAdventureStagePin: View {
    let stage: HomeAdventureStage
    let accent: Color
    let role: HomeAdventureStagePinRole

    var body: some View {
        VStack(spacing: 6) {
            if let badgeTitle = role.badgeTitle {
                Text(badgeTitle)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(role == .current ? Color.black : Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(role.badgeTint, in: Capsule())
                    .shadow(color: role.badgeTint.opacity(0.35), radius: 8)
            }

            ZStack {
                Circle()
                    .fill(nodeFill)
                    .shadow(color: nodeGlow, radius: role.isHighlighted || stage.status == .available ? 18 : 8)

                Circle()
                    .strokeBorder(nodeStroke, lineWidth: role.isHighlighted ? 4 : 2)

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
                    HomeAdventureStageRequirementMarks(stage: stage)
                }

                Text(stageProgressText)
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
        .frame(width: 166, height: 126)
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

    private var nodeStroke: Color {
        switch role {
        case .current:
            return .yellow
        case .next:
            return .orange
        case .regular:
            return Color.white.opacity(0.78)
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
            return Color.green.opacity(0.34)
        }
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
