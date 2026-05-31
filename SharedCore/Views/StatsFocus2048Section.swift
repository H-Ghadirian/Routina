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
                boardGrid
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

    private var boardGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(0..<Focus2048Board.cellCount, id: \.self) { cellIndex in
                let tile = tileByCellIndex[cellIndex]
                StatsFocus2048Cell(
                    tile: tile,
                    colorScheme: colorScheme
                )
                .aspectRatio(1, contentMode: .fit)
                .accessibilityHidden(tile == nil)
            }
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

    private var tileByCellIndex: [Int: Focus2048Tile] {
        Dictionary(
            uniqueKeysWithValues: board.tiles.prefix(Focus2048Board.cellCount).enumerated().map { tileIndex, tile in
                let rowFromBottom = tileIndex / 4
                let column = tileIndex % 4
                let visualRow = 3 - rowFromBottom
                return (visualRow * 4 + column, tile)
            }
        )
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
    let tile: Focus2048Tile?
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tile.map { AnyShapeStyle(tileFill(for: $0)) } ?? AnyShapeStyle(emptyFill))

            if let tile {
                VStack(spacing: 2) {
                    Text("\(tile.value)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(tileTextColor(for: tile))
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)

                    Text("hours")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tileTextColor(for: tile).opacity(0.78))
                        .lineLimit(1)
                }
                .padding(6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.map { "\($0.value) focused hours tile" } ?? "Empty tile")
    }

    private var emptyFill: Color {
        Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.12)
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

    private func tileTextColor(for tile: Focus2048Tile) -> Color {
        tile.value >= 8 ? .white : .primary.opacity(0.82)
    }
}
