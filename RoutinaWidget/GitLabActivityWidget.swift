import WidgetKit
import SwiftUI

struct GitLabActivityEntry: TimelineEntry {
    let date: Date
    let widgetData: GitLabWidgetData?
}

struct GitLabActivityProvider: TimelineProvider {
    func placeholder(in context: Context) -> GitLabActivityEntry {
        GitLabActivityEntry(date: .now, widgetData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GitLabActivityEntry) -> Void) {
        completion(GitLabActivityEntry(date: .now, widgetData: GitLabWidgetData.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GitLabActivityEntry>) -> Void) {
        let entry = GitLabActivityEntry(date: .now, widgetData: GitLabWidgetData.read())
        let nextRefresh = Date().addingTimeInterval(4 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct GitLabActivityWidget: Widget {
    let kind = "GitLabActivityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GitLabActivityProvider()) { entry in
            GitLabActivityWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("GitLab Activity")
        .description("Your GitLab contribution graph for the past year.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
