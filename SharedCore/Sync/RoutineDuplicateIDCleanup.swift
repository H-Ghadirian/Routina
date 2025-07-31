import Foundation
import SwiftData

enum RoutineDuplicateIDCleanup {
    @MainActor
    static func run(in context: ModelContext) {
        do {
            let removedTasks = try dedupe(
                FetchDescriptor<RoutineTask>(),
                in: context,
                id: \.id,
                rank: { $0.lastDone ?? $0.createdAt ?? .distantPast }
            )
            let removedPlaces = try dedupe(
                FetchDescriptor<RoutinePlace>(),
                in: context,
                id: \.id,
                rank: { $0.createdAt }
            )
            let removedLogs = try dedupe(
                FetchDescriptor<RoutineLog>(),
                in: context,
                id: \.id,
                rank: { $0.timestamp ?? .distantPast }
            )
            let removedSessions = try dedupe(
                FetchDescriptor<FocusSession>(),
                in: context,
                id: \.id,
                rank: { $0.completedAt ?? $0.abandonedAt ?? $0.startedAt ?? .distantPast }
            )

            let total = removedTasks + removedPlaces + removedLogs + removedSessions
            guard total > 0 else { return }

            try context.save()
            print("RoutineDuplicateIDCleanup removed \(total) duplicate row(s): tasks=\(removedTasks) places=\(removedPlaces) logs=\(removedLogs) sessions=\(removedSessions)")
        } catch {
            print("RoutineDuplicateIDCleanup failed: \(error)")
        }
    }

    @MainActor
    private static func dedupe<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext,
        id: (Model) -> UUID,
        rank: (Model) -> Date
    ) throws -> Int {
        let rows = try context.fetch(descriptor)
        var grouped: [UUID: [Model]] = [:]
        for row in rows {
            grouped[id(row), default: []].append(row)
        }

        var removed = 0
        for (_, group) in grouped where group.count > 1 {
            let sorted = group.sorted { rank($0) > rank($1) }
            for loser in sorted.dropFirst() {
                context.delete(loser)
                removed += 1
            }
        }
        return removed
    }

    @MainActor
    static func canonical<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext,
        rank: (Model) -> Date
    ) throws -> Model? {
        let matching = try context.fetch(descriptor)
        guard matching.count > 1 else { return matching.first }
        let sorted = matching.sorted { rank($0) > rank($1) }
        for loser in sorted.dropFirst() {
            context.delete(loser)
        }
        return sorted.first
    }
}
