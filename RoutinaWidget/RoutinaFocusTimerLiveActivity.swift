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
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveTimer(context)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    focusProgress(context)
                }
            } compactLeading: {
                Text(context.attributes.taskEmoji)
            } compactTrailing: {
                liveTimer(context)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(deepLinkURL(context))
        }
    }

    private func deepLinkURL(_ taskID: UUID) -> URL {
        URL(string: "routina://task/\(taskID.uuidString)")!
    }

    private func deepLinkURL(_ context: ActivityViewContext<FocusTimerActivityAttributes>) -> URL? {
        context.attributes.taskID.map(deepLinkURL)
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
                Image(systemName: "timer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.teal)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Focus")
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
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
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
}
#endif
