import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum FocusTimerWidgetService {
    static let appGroupID = "group.ir.hamedgh.Routinam"
    static let fileName = "focus_timer_widget.json"
    static let widgetKind = "RoutinaFocusTimerWidget"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
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
            let sessions = try context.fetch(FetchDescriptor<FocusSession>())
            let data = FocusTimerWidgetDataComputer.compute(tasks: tasks, sessions: sessions)
            write(data)
        } catch {
            NSLog("FocusTimerWidgetService: failed to compute focus timer — \(error)")
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

    private static func write(_ data: FocusTimerWidgetData) {
        guard let url = fileURL else { return }
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: url, options: .atomic)
    }
}
