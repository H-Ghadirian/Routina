import Foundation
import SwiftUI

struct FocusSessionCardSnapshot {
    let activeSessionForTask: FocusSession?
    let activeSessionForAnotherTask: FocusSession?
    let completedSessionsForTask: [FocusSession]
    let totalCompletedSeconds: TimeInterval
    let completedFocusBlockCount: Int

    init(taskID: UUID, sessions: [FocusSession]) {
        var activeSessionForTask: FocusSession?
        var activeSessionForAnotherTask: FocusSession?
        var completedSessionsForTask: [FocusSession] = []
        var completedFocusBlockCount = 0

        for session in sessions {
            if session.taskID == taskID {
                if session.completedAt != nil {
                    completedSessionsForTask.append(session)
                    completedFocusBlockCount += FocusBlockProgress.filledBlockCount(for: session.actualDurationSeconds)
                } else if session.abandonedAt == nil && activeSessionForTask == nil {
                    activeSessionForTask = session
                }
            } else if session.completedAt == nil
                        && session.abandonedAt == nil
                        && activeSessionForAnotherTask == nil {
                activeSessionForAnotherTask = session
            }
        }

        completedSessionsForTask.sort {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }

        self.activeSessionForTask = activeSessionForTask
        self.activeSessionForAnotherTask = activeSessionForAnotherTask
        self.completedSessionsForTask = completedSessionsForTask
        self.totalCompletedSeconds = completedSessionsForTask.reduce(0) {
            $0 + $1.actualDurationSeconds
        }
        self.completedFocusBlockCount = completedFocusBlockCount
    }
}

struct FocusSessionBlockProgressView: View {
    let elapsedSeconds: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                FocusSessionBlockHeader(
                    title: "Current session",
                    value: FocusBlockProgress.blockCountText(sessionBlockCount),
                    trailingValue: "Next in \(FocusSessionFormatting.durationText(seconds: nextBlockSeconds))"
                )

                FocusBlockGrid(
                    filledCount: sessionBlockCount,
                    totalCount: visibleSessionBlockCount,
                    blockSize: 12,
                    spacing: 5
                )
            }
        }
    }

    private var sessionBlockCount: Int {
        FocusBlockProgress.filledBlockCount(for: elapsedSeconds)
    }

    private var visibleSessionBlockCount: Int {
        FocusBlockProgress.visibleSessionBlockCount(for: elapsedSeconds)
    }

    private var nextBlockSeconds: TimeInterval {
        FocusBlockProgress.secondsUntilNextBlock(for: elapsedSeconds)
    }
}

struct FocusSessionHistorySummaryView: View {
    let snapshot: FocusSessionCardSnapshot
    var showsAccumulatedBlocks = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                FocusSessionMetricTile(
                    title: "Total",
                    value: FocusSessionFormatting.compactDurationText(seconds: snapshot.totalCompletedSeconds)
                )
                FocusSessionMetricTile(
                    title: "Sessions",
                    value: snapshot.completedSessionsForTask.count.formatted()
                )
                if let latest = snapshot.completedSessionsForTask.first?.completedAt {
                    FocusSessionMetricTile(
                        title: "Latest",
                        value: latest.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }

            if showsAccumulatedBlocks && snapshot.completedFocusBlockCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    FocusSessionBlockHeader(
                        title: "Accumulated blocks",
                        value: FocusBlockProgress.blockCountText(snapshot.completedFocusBlockCount),
                        trailingValue: FocusSessionFormatting.compactDurationText(
                            seconds: TimeInterval(snapshot.completedFocusBlockCount) * FocusBlockProgress.blockDurationSeconds
                        )
                    )

                    FocusBlockGrid(
                        filledCount: snapshot.completedFocusBlockCount,
                        totalCount: snapshot.completedFocusBlockCount,
                        blockSize: 8,
                        spacing: 4
                    )
                }
            }
        }
    }
}

struct FocusSessionHistoryListView: View {
    let sessions: [FocusSession]
    @Binding var isShowingAllHistory: Bool
    let onEdit: (FocusSession) -> Void

    var body: some View {
        let visibleSessions = isShowingAllHistory
            ? sessions
            : Array(sessions.prefix(3))

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(isShowingAllHistory ? "Focus history" : "Recent focus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(sessions.count.formatted())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.14))
                    )
            }

            ForEach(visibleSessions) { session in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                            .font(.caption.weight(.semibold))

                        Text(recentSessionDurationText(session))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        onEdit(session)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Edit focus session")
                }
                .padding(.vertical, 4)
            }

            if sessions.count > 3 {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isShowingAllHistory.toggle()
                    }
                } label: {
                    Label(
                        isShowingAllHistory ? "Show less" : "Show all \(sessions.count) sessions",
                        systemImage: isShowingAllHistory ? "chevron.up.circle" : "chevron.down.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(isShowingAllHistory ? "Show fewer focus sessions" : "Show all focus sessions")
            }
        }
    }

    private func recentSessionDurationText(_ session: FocusSession) -> String {
        let durationText = FocusSessionFormatting.compactDurationText(seconds: session.actualDurationSeconds)
        let blockCount = FocusBlockProgress.filledBlockCount(for: session.actualDurationSeconds)
        guard blockCount > 0 else { return durationText }
        return "\(durationText), \(FocusBlockProgress.blockCountText(blockCount))"
    }
}

private struct FocusSessionBlockHeader: View {
    let title: String
    let value: String
    let trailingValue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)

            Spacer(minLength: 8)

            Text(trailingValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct FocusSessionMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FocusBlockGrid: View {
    let filledCount: Int
    let totalCount: Int
    var tint: Color = .teal
    var blockSize: CGFloat
    var spacing: CGFloat

    private var safeTotalCount: Int {
        max(0, totalCount)
    }

    private var safeFilledCount: Int {
        min(max(0, filledCount), safeTotalCount)
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: blockSize, maximum: blockSize),
                spacing: spacing,
                alignment: .leading
            ),
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(Array(0..<safeTotalCount), id: \.self) { index in
                let isFilled = index < safeFilledCount

                RoundedRectangle(cornerRadius: max(2, blockSize * 0.25), style: .continuous)
                    .fill(isFilled ? tint.opacity(0.86) : Color.secondary.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: max(2, blockSize * 0.25), style: .continuous)
                            .stroke(
                                isFilled ? tint.opacity(0.25) : Color.secondary.opacity(0.18),
                                lineWidth: 1
                            )
                    }
                    .frame(width: blockSize, height: blockSize)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(FocusBlockProgress.blockCountText(safeFilledCount)) filled")
    }
}
