#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import SwiftUI
import WidgetKit

struct RoutinaFocusTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerActivityAttributes.self) { context in
            FocusTimerLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.025, green: 0.031, blue: 0.04))
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
        if !context.state.isCountUp, let endDate = context.state.endDate {
            FocusTimerProgressBar(startedAt: context.state.startedAt, endDate: endDate)
        }
    }
}

private struct FocusTimerLiveActivityLockScreenView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Focusing on")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Text(context.attributes.taskName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            liveTimer
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.teal)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if !context.state.isCountUp {
                progressLine
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .widgetURL(deepLinkURL)
    }

    @ViewBuilder
    private var progressLine: some View {
        if let endDate = context.state.endDate {
            FocusTimerProgressBar(startedAt: context.state.startedAt, endDate: endDate)
        }
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

    private var focusKind: FocusTimerActivityAttributes.FocusKind {
        context.attributes.focusKind ?? .task
    }

    private var deepLinkURL: URL? {
        let targetID = context.attributes.targetID ?? context.attributes.taskID
        guard let targetID else { return nil }
        return URL(string: "routina://\(focusKind.deepLinkPath)/\(targetID.uuidString)")
    }
}

private struct FocusTimerProgressBar: View {
    let startedAt: Date
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.13))

                    Capsule()
                        .fill(.teal)
                        .frame(width: filledWidth(in: proxy.size.width, at: timeline.date))
                }
            }
        }
        .frame(height: 4)
        .accessibilityLabel("Focus progress")
        .accessibilityValue(progressAccessibilityValue(at: .now))
    }

    private func filledWidth(in width: CGFloat, at date: Date) -> CGFloat {
        let progress = progress(at: date)
        guard progress > 0 else { return 0 }
        return max(4, width * progress)
    }

    private func progress(at date: Date) -> CGFloat {
        let duration = max(endDate.timeIntervalSince(startedAt), 1)
        let elapsed = min(max(date.timeIntervalSince(startedAt), 0), duration)
        return CGFloat(elapsed / duration)
    }

    private func progressAccessibilityValue(at date: Date) -> String {
        let percent = Int((progress(at: date) * 100).rounded())
        return "\(percent)%"
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
}
#endif
