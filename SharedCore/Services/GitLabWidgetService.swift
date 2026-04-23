import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum GitLabWidgetService {
    static let appGroupID = "group.ir.hamedgh.Routinam"
    static let fileName = "gitlab_widget.json"
    static let widgetKind = "GitLabActivityWidget"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func write(_ data: GitLabWidgetData) {
        guard let url = fileURL else {
            NSLog("GitLabWidgetService: app group container unavailable (check entitlement \(appGroupID))")
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let json = try encoder.encode(data)
            try json.write(to: url, options: .atomic)
            NSLog("GitLabWidgetService: wrote \(json.count) bytes for @\(data.username) to \(url.path)")
        } catch {
            NSLog("GitLabWidgetService: write failed — \(error.localizedDescription)")
        }
    }

    static func reload() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
#endif
    }

    static func writeAndReload(_ data: GitLabWidgetData) {
        write(data)
        reload()
    }

    static func clear() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        reload()
    }
}
