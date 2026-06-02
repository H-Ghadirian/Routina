import SwiftUI
import WidgetKit

struct FocusTimerEntry: TimelineEntry {
    let date: Date
    let focus: FocusTimerWidgetData
}

struct FocusTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusTimerEntry {
        FocusTimerEntry(date: .now, focus: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusTimerEntry) -> Void) {
        completion(FocusTimerEntry(date: .now, focus: context.isPreview ? .placeholder : FocusTimerWidgetData.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusTimerEntry>) -> Void) {
        let focus = FocusTimerWidgetData.read()
        let entry = FocusTimerEntry(date: .now, focus: focus)

        if let endDate = focus.endDate, endDate > .now {
            completion(Timeline(entries: [entry], policy: .after(endDate)))
        } else {
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }
}

struct RoutinaFocusTimerWidget: Widget {
    let kind = "RoutinaFocusTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusTimerProvider()) { entry in
            FocusTimerWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("Shows the current Routina focus session timer.")
#if os(macOS)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
#else
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
#endif
    }
}

private struct FocusTimerWidgetView: View {
    let entry: FocusTimerEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
#if !os(macOS)
        case .accessoryCircular:
            circularAccessory
        case .accessoryRectangular:
            rectangularAccessory
#endif
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 7) {
            header
            Spacer(minLength: 0)
            timerText
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            taskTitle
                .font(.headline.weight(.semibold))
                .layoutPriority(1)
        }
        .padding(10)
#else
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            timerText
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            taskLine
            stateLine
        }
        .padding(12)
#endif
    }

    private var mediumLayout: some View {
#if os(macOS)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                header
                taskTitle
                    .font(.title3.weight(.semibold))
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                timerText
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                timerAccessory
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
#else
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                header
                taskLine
                    .font(.headline)
                stateLine
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                timerText
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                timerAccessory
            }
        }
        .padding(14)
#endif
    }

    private var circularAccessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: focusSystemImage)
                    .font(.caption2.weight(.semibold))
                if entry.focus.isActive {
                    timerText
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                } else {
                    Text("Idle")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private var rectangularAccessory: some View {
        HStack(spacing: 6) {
            Image(systemName: focusSystemImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.focus.isActive ? entry.focus.taskName : "No focus")
                    .lineLimit(1)
                timerText
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: focusSystemImage)
                .foregroundStyle(.teal)
            Text("Focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var timerText: some View {
        if entry.focus.isActive {
            if entry.focus.isPaused {
                Text(staticTimerText)
            } else if entry.focus.isCountUp, let adjustedStartedAt = entry.focus.adjustedStartedAt {
                Text(adjustedStartedAt, style: .timer)
            } else if let endDate = entry.focus.endDate {
                Text(timerInterval: Date.now...endDate, countsDown: true)
            } else {
                Text("--:--")
            }
        } else {
            Text("--:--")
        }
    }

    private var taskLine: some View {
        HStack(spacing: 5) {
            Text(entry.focus.taskEmoji)
            Text(entry.focus.isActive ? entry.focus.taskName : "No active session")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var taskTitle: some View {
        Text(entry.focus.isActive ? entry.focus.taskName : "No active session")
            .lineLimit(2)
            .minimumScaleFactor(0.68)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var stateLine: some View {
        Text(entry.focus.isActive ? activeStateText : "Start focus from a task")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Image(systemName: statusSystemImage)
                .font(.caption2.weight(.bold))
            Text(entry.focus.isActive ? activeStateText : "Idle")
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(entry.focus.isActive ? .teal : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill((entry.focus.isActive ? Color.teal : Color.secondary).opacity(0.14))
        )
    }

    @ViewBuilder
    private var timerAccessory: some View {
        if entry.focus.plannedDurationSeconds > 0 {
            progressView
                .frame(width: 118)
        } else if entry.focus.isActive {
            statusChip
        }
    }

    @ViewBuilder
    private var progressView: some View {
        if entry.focus.isPaused, entry.focus.plannedDurationSeconds > 0 {
            ProgressView(value: entry.focus.progress(at: entry.date))
                .tint(.teal)
        } else if let startedAt = entry.focus.adjustedStartedAt, entry.focus.plannedDurationSeconds > 0 {
            ProgressView(
                timerInterval: startedAt...startedAt.addingTimeInterval(entry.focus.plannedDurationSeconds),
                countsDown: false
            )
            .tint(.teal)
        } else if entry.focus.isPaused {
            EmptyView()
        }
    }

    private var focusSystemImage: String {
        if entry.focus.isPaused {
            return "pause.circle.fill"
        }
        return entry.focus.isActive ? "timer" : "timer.square"
    }

    private var statusSystemImage: String {
        if entry.focus.isPaused {
            return "pause.fill"
        }
        return entry.focus.isCountUp ? "arrow.up.right" : "target"
    }

    private var activeStateText: String {
        if entry.focus.isPaused {
            return "Paused"
        }
        return entry.focus.isCountUp ? "Elapsed" : "Remaining"
    }

    private var staticTimerText: String {
        let seconds = entry.focus.isCountUp
            ? entry.focus.elapsedSeconds(at: entry.date)
            : entry.focus.remainingSeconds(at: entry.date)
        return Self.durationText(seconds: seconds)
    }

    private static func durationText(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview(as: .systemSmall) {
    RoutinaFocusTimerWidget()
} timeline: {
    FocusTimerEntry(date: .now, focus: .placeholder)
}

#Preview(as: .systemMedium) {
    RoutinaFocusTimerWidget()
} timeline: {
    FocusTimerEntry(date: .now, focus: .placeholder)
}
