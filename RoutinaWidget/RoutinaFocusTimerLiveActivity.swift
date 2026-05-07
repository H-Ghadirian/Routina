#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import SwiftUI
import WidgetKit

struct RoutinaFocusTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerActivityAttributes.self) { context in
            FocusTimerLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.teal)
                .widgetURL(deepLinkURL(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    focusTitle(context)
                        .widgetURL(deepLinkURL(context))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveTimer(context)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .widgetURL(deepLinkURL(context))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    focusProgress(context)
                        .widgetURL(deepLinkURL(context))
                }
            } compactLeading: {
                Text(context.attributes.taskEmoji)
                    .widgetURL(deepLinkURL(context))
            } compactTrailing: {
                liveTimer(context)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .widgetURL(deepLinkURL(context))
            } minimal: {
                Image(systemName: focusKind(context).systemImage)
                    .widgetURL(deepLinkURL(context))
            }
            .widgetURL(deepLinkURL(context))
        }
    }

    private func deepLinkURL(
        _ kind: FocusTimerActivityAttributes.FocusKind,
        targetID: UUID
    ) -> URL {
        URL(string: "routina://\(kind.deepLinkPath)/\(targetID.uuidString)")!
    }

    private func deepLinkURL(_ context: ActivityViewContext<FocusTimerActivityAttributes>) -> URL? {
        let kind = focusKind(context)
        guard let targetID = context.attributes.targetID ?? context.attributes.taskID else { return nil }
        return deepLinkURL(kind, targetID: targetID)
    }

    private func focusKind(
        _ context: ActivityViewContext<FocusTimerActivityAttributes>
    ) -> FocusTimerActivityAttributes.FocusKind {
        context.attributes.focusKind ?? .task
    }

    private func focusTitle(_ context: ActivityViewContext<FocusTimerActivityAttributes>) -> some View {
        HStack(spacing: 6) {
            Text(context.attributes.taskEmoji)
            Text(context.attributes.taskName)
                .lineLimit(1)
        }
        .font(.headline)
    }

    @ViewBuilder
    private func liveTimer(_ context: ActivityViewContext<FocusTimerActivityAttributes>) -> some View {
        if context.state.isCountUp {
            Text(context.state.startedAt, style: .timer)
        } else if let endDate = context.state.endDate {
            Text(timerInterval: Date.now...endDate, countsDown: true)
        } else {
            Text("--:--")
        }
    }

    @ViewBuilder
    private func focusProgress(_ context: ActivityViewContext<FocusTimerActivityAttributes>) -> some View {
        if let endDate = context.state.endDate {
            ProgressView(timerInterval: context.state.startedAt...endDate, countsDown: false)
                .tint(.teal)
        } else {
            ProgressView()
                .tint(.teal)
        }
    }
}

private struct FocusTimerLiveActivityLockScreenView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.teal.opacity(0.16))
                Image(systemName: focusKind.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.teal)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(focusKind.lockScreenTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 5) {
                    Text(context.attributes.taskEmoji)
                    Text(context.attributes.taskName)
                        .lineLimit(1)
                }
                .font(.headline)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 5) {
                liveTimer
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                progress
                    .frame(width: 96)

                if let deepLinkURL {
                    Link(destination: deepLinkURL) {
                        Label("Details", systemImage: "arrow.up.forward.app")
                            .font(.caption2.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .foregroundStyle(.teal)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .widgetURL(deepLinkURL)
    }

    @ViewBuilder
    private var liveTimer: some View {
        if context.state.isCountUp {
            Text(context.state.startedAt, style: .timer)
        } else if let endDate = context.state.endDate {
            Text(timerInterval: Date.now...endDate, countsDown: true)
        } else {
            Text("--:--")
        }
    }

    @ViewBuilder
    private var progress: some View {
        if let endDate = context.state.endDate {
            ProgressView(timerInterval: context.state.startedAt...endDate, countsDown: false)
                .tint(.teal)
        } else {
            ProgressView()
                .tint(.teal)
        }
    }

    private var focusKind: FocusTimerActivityAttributes.FocusKind {
        context.attributes.focusKind ?? .task
    }

    private var deepLinkURL: URL? {
        let targetID = context.attributes.targetID ?? context.attributes.taskID
        guard let targetID else { return nil }
        return URL(string: "routina://\(focusKind.deepLinkPath)/\(targetID.uuidString)")
    }
}

private extension FocusTimerActivityAttributes.FocusKind {
    var deepLinkPath: String {
        switch self {
        case .task:
            return "task"
        case .sprint:
            return "sprint"
        }
    }

    var systemImage: String {
        switch self {
        case .task:
            return "timer"
        case .sprint:
            return "flag.checkered"
        }
    }

    var lockScreenTitle: String {
        switch self {
        case .task:
            return "Focus"
        case .sprint:
            return "Sprint Focus"
        }
    }
}
#endif
