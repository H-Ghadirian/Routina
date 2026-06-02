import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum WidgetStatsService {
    static let appGroupID = "group.ir.hamedgh.Routinam"
    static let statsFileName = "widget_stats.json"
    static let widgetKind = "RoutinaStatsWidget"
    static let todayFocusWidgetKind = "RoutinaTodayFocusWidget"

    static var reloadWidgetKinds: [String] {
        #if os(macOS)
        [widgetKind, todayFocusWidgetKind]
        #else
        [widgetKind]
        #endif
    }

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
            let completedKindRawValue = RoutineLogKind.completed.rawValue
            let completedLogsDescriptor = FetchDescriptor<RoutineLog>(
                predicate: #Predicate { log in
                    log.kindRawValue == completedKindRawValue && log.timestamp != nil
                }
            )
            let logs = try context.fetch(completedLogsDescriptor)
            let focusSessionsDescriptor = FetchDescriptor<FocusSession>(
                predicate: #Predicate { session in
                    session.abandonedAt == nil
                }
            )
            let focusSessions = try context.fetch(focusSessionsDescriptor)
            let sprintFocusSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
            let stats = WidgetStatsComputer.compute(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                sprintFocusSessions: sprintFocusSessions
            )
            write(stats)
        } catch {
            NSLog("WidgetStatsService: failed to compute stats — \(error)")
        }
    }

    @MainActor
    public static func refreshAndReload(using context: ModelContext) {
        refresh(using: context)
#if canImport(WidgetKit)
        reloadTimelines()
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

#if canImport(WidgetKit)
    private static func reloadTimelines() {
        for kind in reloadWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
#endif
}
