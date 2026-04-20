import WidgetKit
import SwiftUI

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetStats
}

struct RoutinaStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, stats: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: .now, stats: WidgetStats.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let stats = WidgetStats.read()
        let entry = StatsEntry(date: .now, stats: stats)

        // Refresh at the start of the next day so "today" counts reset correctly.
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct RoutinaStatsWidget: Widget {
    let kind = "RoutinaStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoutinaStatsProvider()) { entry in
            RoutinaWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Routina Stats")
        .description("Today's tasks, completions, and streak at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
