import ComposableArchitecture
import SwiftUI

struct HomeMacHomeToolbarContent: ToolbarContent {
    enum Mode {
        case board
        case goals
        case standard
    }

    let mode: Mode
    let showsDetailModePicker: Bool
    let showsProgressModePicker: Bool
    @Binding var detailMode: MacHomeDetailMode
    @Binding var progressMode: MacHomeProgressMode
    let locationSnapshot: LocationSnapshot
    let planTodayTaskCount: Int
    let activePlanFocusSession: FocusSession?
    let isPlanFocusStartDisabled: Bool
    let onPlaceCheckInMapRequested: () -> Void
    let onStartPlanFocus: (TimeInterval) -> Void
    let onPausePlanFocus: (FocusSession) -> Void
    let onResumePlanFocus: (FocusSession) -> Void
    let onFinishPlanFocus: (FocusSession) -> Void
    let onAbandonPlanFocus: (FocusSession) -> Void

    var body: some ToolbarContent {
        switch mode {
        case .board:
            boardToolbar
        case .goals:
            goalsToolbar
        case .standard:
            standardToolbar
        }
    }

    @ToolbarContentBuilder
    private var boardToolbar: some ToolbarContent {
        navigationToolbarItems
        detailModeToolbarItem
    }

    @ToolbarContentBuilder
    private var goalsToolbar: some ToolbarContent {
        navigationToolbarItems
    }

    @ToolbarContentBuilder
    private var standardToolbar: some ToolbarContent {
        navigationToolbarItems
        detailModeToolbarItem
    }

    @ToolbarContentBuilder
    private var navigationToolbarItems: some ToolbarContent {
        RoutinaMacPlaceCheckInToolbarItem(
            locationSnapshot: locationSnapshot,
            onMapRequested: onPlaceCheckInMapRequested
        )

        if let activePlanFocusSession {
            ToolbarItem(placement: .navigation) {
                HomeMacActivePlanFocusToolbarButton(
                    session: activePlanFocusSession,
                    onPause: onPausePlanFocus,
                    onResume: onResumePlanFocus,
                    onFinish: onFinishPlanFocus,
                    onAbandon: onAbandonPlanFocus
                )
            }
        } else if planTodayTaskCount > 0 {
            ToolbarItem(placement: .navigation) {
                HomeMacPlanFocusToolbarButton(
                    plannedTaskCount: planTodayTaskCount,
                    isDisabled: isPlanFocusStartDisabled,
                    onStart: onStartPlanFocus
                )
            }
        }

        RoutinaMacFocusTimerToolbarItem(hiddenKinds: [.unassigned])
    }

    @ToolbarContentBuilder
    private var detailModeToolbarItem: some ToolbarContent {
        if showsDetailModePicker {
            ToolbarItem(placement: .principal) {
                MacHomeDetailModePicker(selection: $detailMode)
            }
        } else if showsProgressModePicker {
            ToolbarItem(placement: .principal) {
                MacHomeProgressModePicker(selection: $progressMode)
            }
        }
    }
}

private struct HomeMacActivePlanFocusToolbarButton: View {
    let session: FocusSession
    let onPause: (FocusSession) -> Void
    let onResume: (FocusSession) -> Void
    let onFinish: (FocusSession) -> Void
    let onAbandon: (FocusSession) -> Void

    var body: some View {
        Menu {
            Button {
                if session.isPaused {
                    onResume(session)
                } else {
                    onPause(session)
                }
            } label: {
                Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
            }

            Button {
                onFinish(session)
            } label: {
                Label("Finish", systemImage: "checkmark.circle.fill")
            }

            Divider()

            Button(role: .destructive) {
                onAbandon(session)
            } label: {
                Label("Abandon", systemImage: "xmark.circle")
            }
        } label: {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                planFocusToolbarLabel {
                    Image(systemName: session.isPaused ? "pause.fill" : "stopwatch.fill")
                        .font(.caption.weight(.semibold))

                    Text(activeTimeText(at: context.date))
                        .font(.caption.monospacedDigit().weight(.semibold))

                    Text(activeStatusText(at: context.date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .controlSize(.small)
        .help("Start Focus Timer running")
        .padding(.trailing, 8)
    }

    private func activeTimeText(at date: Date) -> String {
        let elapsedSeconds = session.activeDurationSeconds(at: date)
        guard session.plannedDurationSeconds > 0 else {
            return FocusSessionFormatting.durationText(seconds: elapsedSeconds)
        }
        return FocusSessionFormatting.durationText(
            seconds: max(0, session.plannedDurationSeconds - elapsedSeconds)
        )
    }

    private func activeStatusText(at date: Date) -> String {
        if session.isPaused {
            return "paused"
        }
        if session.plannedDurationSeconds > 0,
           session.activeDurationSeconds(at: date) > session.plannedDurationSeconds {
            return "overtime"
        }
        return session.plannedDurationSeconds > 0 ? "left" : "elapsed"
    }
}

private struct HomeMacPlanFocusToolbarButton: View {
    let plannedTaskCount: Int
    let isDisabled: Bool
    let onStart: (TimeInterval) -> Void

    private let durationOptions: [TimeInterval] = [
        15 * 60,
        25 * 60,
        45 * 60,
        60 * 60,
        90 * 60,
    ]

    var body: some View {
        Menu {
            Button {
                onStart(0)
            } label: {
                Label("Count up", systemImage: "stopwatch")
            }

            Divider()

            ForEach(durationOptions, id: \.self) { duration in
                Button(FocusSessionFormatting.compactDurationText(seconds: duration)) {
                    onStart(duration)
                }
            }
        } label: {
            planFocusToolbarLabel {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.semibold))

                Text("Start Focus Timer")
                    .font(.caption.weight(.semibold))
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .controlSize(.small)
        .disabled(isDisabled)
        .help(planFocusHelpTitle)
        .padding(.trailing, 8)
    }

    private var planFocusHelpTitle: String {
        let taskText = plannedTaskCount == 1 ? "1 planned task" : "\(plannedTaskCount) planned tasks"
        return isDisabled ? "Stop the active focus timer before starting another focus timer" : "Start Focus Timer for \(taskText)"
    }
}

@MainActor
private func planFocusToolbarLabel<Content: View>(
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(spacing: 6) {
        content()
    }
    .foregroundStyle(.orange)
    .padding(.horizontal, 12)
    .frame(height: 28)
    .routinaGlassPill(tint: .orange, tintOpacity: 0.12, interactive: true)
    .overlay(
        Capsule(style: .continuous)
            .stroke(Color.orange.opacity(0.22), lineWidth: 0.75)
    )
    .contentShape(Capsule(style: .continuous))
    .fixedSize(horizontal: true, vertical: false)
}

struct HomeMacBoardInspectorToolbarButton: View {
    let isPresented: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: isPresented ? "Hide Board Details" : "Show Board Details",
            systemImage: "sidebar.right"
        ) {
            onToggle()
        }
        .help(isPresented ? "Hide board details" : "Show board details")
    }
}
