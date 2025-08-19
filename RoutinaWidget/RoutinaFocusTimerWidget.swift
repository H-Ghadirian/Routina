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
    }

    private var mediumLayout: some View {
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
                progressView
                    .frame(width: 118)
            }
        }
        .padding(14)
    }

    private var circularAccessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: entry.focus.isActive ? "timer" : "moon.zzz")
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
            Image(systemName: entry.focus.isActive ? "timer" : "moon.zzz")
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
            Image(systemName: entry.focus.isActive ? "timer" : "timer.square")
                .foregroundStyle(.teal)
            Text("Focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var timerText: some View {
        if entry.focus.isActive, let startedAt = entry.focus.startedAt {
            if entry.focus.isCountUp {
                Text(startedAt, style: .timer)
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

    private var stateLine: some View {
        Text(entry.focus.isActive ? (entry.focus.isCountUp ? "Counting up" : "In focus") : "Start focus from a task")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var progressView: some View {
        if let startedAt = entry.focus.startedAt, entry.focus.plannedDurationSeconds > 0 {
            ProgressView(
                timerInterval: startedAt...startedAt.addingTimeInterval(entry.focus.plannedDurationSeconds),
                countsDown: false
            )
            .tint(.teal)
        } else if entry.focus.isActive {
            ProgressView()
                .tint(.teal)
        }
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
