import WidgetKit
import SwiftUI

struct GitHubActivityEntry: TimelineEntry {
    let date: Date
    let widgetData: GitHubWidgetData?
}

struct GitHubActivityProvider: TimelineProvider {
    func placeholder(in context: Context) -> GitHubActivityEntry {
        GitHubActivityEntry(date: .now, widgetData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GitHubActivityEntry) -> Void) {
        completion(GitHubActivityEntry(date: .now, widgetData: GitHubWidgetData.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GitHubActivityEntry>) -> Void) {
        let entry = GitHubActivityEntry(date: .now, widgetData: GitHubWidgetData.read())
        let nextRefresh = Date().addingTimeInterval(4 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct GitHubActivityWidget: Widget {
    let kind = "GitHubActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GitHubActivityProvider()) { entry in
            GitHubActivityWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("GitHub Activity")
        .description("Your GitHub contribution graph for the past year.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
