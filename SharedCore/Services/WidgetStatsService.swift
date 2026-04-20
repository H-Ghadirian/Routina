import Foundation
import SwiftData

public enum WidgetStatsService {
    static let appGroupID = "group.ir.hamedgh.Routinam"
    static let statsFileName = "widget_stats.json"

    static var statsFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(statsFileName)
    }

    @MainActor
    public static func refresh(using container: ModelContainer) {
        let context = ModelContext(container)
        do {
            let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            let logs = try context.fetch(FetchDescriptor<RoutineLog>())
            let stats = WidgetStatsComputer.compute(tasks: tasks, logs: logs)
            write(stats)
        } catch {
            NSLog("WidgetStatsService: failed to compute stats — \(error)")
        }
    }

    private static func write(_ stats: WidgetStats) {
        guard let url = statsFileURL else { return }
        guard let data = try? JSONEncoder().encode(stats) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
