import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum WidgetStatsService {
    static let appGroupID = "group.ir.hamedgh.Routinam"
    static let statsFileName = "widget_stats.json"
    static let widgetKind = "RoutinaStatsWidget"

    static var statsFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(statsFileName)
    }

    @MainActor
    public static func refresh(using container: ModelContainer) {
        let context = ModelContext(container)
        refresh(using: context)
    }

    @MainActor
    public static func refresh(using context: ModelContext) {
        do {
            let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            let logs = try context.fetch(FetchDescriptor<RoutineLog>())
            let stats = WidgetStatsComputer.compute(tasks: tasks, logs: logs)
            write(stats)
        } catch {
            NSLog("WidgetStatsService: failed to compute stats — \(error)")
        }
    }

    @MainActor
    public static func refreshAndReload(using context: ModelContext) {
        refresh(using: context)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
#endif
    }

    @MainActor
    public static func refreshAndReload(using container: ModelContainer) {
        let context = ModelContext(container)
        refreshAndReload(using: context)
    }

    private static func write(_ stats: WidgetStats) {
        guard let url = statsFileURL else { return }
        guard let data = try? JSONEncoder().encode(stats) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
