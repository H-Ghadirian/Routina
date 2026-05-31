import SwiftUI

struct StatsFocus2048Section: View {
    let totalFocusSeconds: TimeInterval
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    private var board: Focus2048Board {
        Focus2048Stats.board(totalFocusSeconds: totalFocusSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Focus 2048",
                subtitle: "Each full 2 focused hours compounds into 2048-style hour tiles."
            ) {
                StatsSmallHighlightBadge(
                    title: "Largest tile",
                    value: largestTileText,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                earnedTilesPanel
                progressPanel
            }

            StatsChartInsightRow(
                insights: insights,
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.focus2048.section")
    }

    private var earnedTilesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Earned tiles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(earnedTileSummary)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: tileColumns, alignment: .leading, spacing: 10) {
                ForEach(earnedTiles) { tile in
                    StatsFocus2048Cell(
                        tile: tile,
                        isPreview: false,
                        progress: 1,
                        colorScheme: colorScheme
                    )
                    .aspectRatio(1, contentMode: .fit)
                }

                StatsFocus2048Cell(
                    tile: nextPreviewTile,
                    isPreview: true,
                    progress: board.nextTileProgress,
                    colorScheme: colorScheme
                )
                .aspectRatio(1, contentMode: .fit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(boardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
        )
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(progressTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(progressValue)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.12))

                    Capsule(style: .continuous)
                        .fill(progressFill)
                        .frame(width: max(8, proxy.size.width * board.nextTileProgress))
                }
            }
            .frame(height: 9)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
        )
    }

    private var earnedTiles: [Focus2048Tile] {
        Array(board.tiles.prefix(Focus2048Board.cellCount))
    }

    private var nextPreviewTile: Focus2048Tile {
        Focus2048Tile(id: -1, value: 2)
    }

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 82, maximum: 126), spacing: 10)]
    }

    private var earnedTileSummary: String {
        guard !earnedTiles.isEmpty else {
            return "Building first 2h tile"
        }
        return "\(earnedTiles.count.formatted()) \(earnedTiles.count == 1 ? "tile" : "tiles")"
    }

    private var largestTileText: String {
        guard board.largestTileValue > 0 else { return "None" }
        return "\(board.largestTileValue)h"
    }

    private var progressTitle: String {
        board.completedBaseTileCount == 0 ? "Progress to first tile" : "Progress to next 2 tile"
    }

    private var progressValue: String {
        if board.partialTileSeconds <= 0 {
            return "\(durationText(board.baseTileSeconds)) left"
        }
        return "\(durationText(board.secondsUntilNextBaseTile)) left"
    }

    private var insights: [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: selectedRange.periodDescription
            ),
            StatsChartInsight(
                systemImage: "timer",
                text: "Total focus: \(chartPresentation.focusDurationText(board.totalFocusSeconds))"
            ),
            StatsChartInsight(
                systemImage: "square.grid.3x3.fill",
                text: "\(board.completedBaseTileCount.formatted()) full 2h \(board.completedBaseTileCount == 1 ? "chunk" : "chunks")"
            )
        ]
    }

    private var boardBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var progressFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.cyan.opacity(colorScheme == .dark ? 0.88 : 0.72),
                Color.green.opacity(colorScheme == .dark ? 0.78 : 0.64)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        FocusSessionFormatting.compactDurationText(seconds: seconds)
    }
}

private struct StatsFocus2048Cell: View {
    let tile: Focus2048Tile
    let isPreview: Bool
    let progress: Double
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPreview ? AnyShapeStyle(previewFill) : AnyShapeStyle(tileFill(for: tile)))

            if isPreview, progress > 0 {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tileFill(for: tile))
                            .opacity(colorScheme == .dark ? 0.34 : 0.28)
                            .frame(height: proxy.size.height * min(max(progress, 0), 1))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            VStack(spacing: 2) {
                Text("\(tile.value)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(tileTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)

                Text(isPreview ? "next" : "hours")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tileTextColor.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(6)
        }
        .overlay(tileBorder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var previewFill: Color {
        Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.1)
    }

    @ViewBuilder
    private var tileBorder: some View {
        if isPreview {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    Color.secondary.opacity(colorScheme == .dark ? 0.38 : 0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        }
    }

    private func tileFill(for tile: Focus2048Tile) -> LinearGradient {
        let colors = tileColors(for: tile.value)
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func tileColors(for value: Int) -> [Color] {
        switch value {
        case 2:
            return [Color.cyan.opacity(0.52), Color.teal.opacity(0.46)]
        case 4:
            return [Color.green.opacity(0.58), Color.mint.opacity(0.48)]
        case 8:
            return [Color.blue.opacity(0.66), Color.cyan.opacity(0.52)]
        case 16:
            return [Color.indigo.opacity(0.68), Color.blue.opacity(0.58)]
        case 32:
            return [Color.purple.opacity(0.72), Color.pink.opacity(0.56)]
        case 64:
            return [Color.orange.opacity(0.78), Color.red.opacity(0.58)]
        case 128:
            return [Color.yellow.opacity(0.82), Color.orange.opacity(0.66)]
        case 256:
            return [Color.mint.opacity(0.78), Color.green.opacity(0.62)]
        case 512:
            return [Color.cyan.opacity(0.82), Color.blue.opacity(0.66)]
        case 1024:
            return [Color.pink.opacity(0.78), Color.purple.opacity(0.64)]
        default:
            return [Color.orange.opacity(0.88), Color.yellow.opacity(0.7)]
        }
    }

    private var tileTextColor: Color {
        if isPreview {
            return .secondary
        }
        return tile.value >= 8 ? .white : .primary.opacity(0.82)
    }

    private var accessibilityLabel: String {
        if isPreview {
            return "Next 2 focused hours tile preview"
        }
        return "\(tile.value) focused hours tile"
    }
}
