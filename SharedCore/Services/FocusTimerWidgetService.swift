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
            let session = try activeFocusSession(in: context)
            let activeTask = try session.flatMap { session in
                session.isTaskFocus ? try task(for: session.taskID, in: context) : nil
            }
            let data = FocusTimerWidgetDataComputer.compute(
                tasks: activeTask.map { [$0] } ?? [],
                sessions: session.map { [$0] } ?? []
            )
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

    @MainActor
    private static func activeFocusSession(in context: ModelContext) throws -> FocusSession? {
        let activeSessionPredicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: activeSessionPredicate,
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func task(for taskID: UUID, in context: ModelContext) throws -> RoutineTask? {
        var descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
