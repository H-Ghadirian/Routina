import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum GitHubWidgetService {
    static let appGroupID = "group.ir.hamedgh.Routinam"
    static let fileName = "github_widget.json"
    static let widgetKind = "GitHubActivityWidget"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func write(_ data: GitHubWidgetData) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(data) else { return }
        try? json.write(to: url, options: .atomic)
    }

    static func reload() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
#endif
    }

    static func writeAndReload(_ data: GitHubWidgetData) {
        write(data)
        reload()
    }

    static func clear() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        reload()
    }
}
