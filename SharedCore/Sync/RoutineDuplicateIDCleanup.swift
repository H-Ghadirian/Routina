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
            let removedAwaySessions = try dedupe(
                FetchDescriptor<AwaySession>(),
                in: context,
                id: \.id,
                rank: { $0.finishedAt ?? $0.startedAt ?? $0.createdAt ?? .distantPast }
            )
            let removedDuplicateSleepSessions = try dedupe(
                FetchDescriptor<SleepSession>(),
                in: context,
                id: \.id,
                rank: { $0.endedAt ?? $0.startedAt ?? $0.updatedAt ?? .distantPast }
            )
            let removedOverlappingSleepSessions = try mergeOverlappingSleepSessions(in: context)
            let removedSleepSessions = removedDuplicateSleepSessions + removedOverlappingSleepSessions
            let removedPlaceCheckIns = try dedupe(
                FetchDescriptor<PlaceCheckInSession>(),
                in: context,
                id: \.id,
                rank: { $0.endedAt ?? $0.startedAt ?? $0.createdAt ?? .distantPast }
            )
            let removedEmotions = try dedupe(
                FetchDescriptor<EmotionLog>(),
                in: context,
                id: \.id,
                rank: { $0.updatedAt ?? $0.createdAt ?? .distantPast }
            )
            let removedNotes = try dedupe(
                FetchDescriptor<RoutineNote>(),
                in: context,
                id: \.id,
                rank: { $0.updatedAt ?? $0.createdAt ?? .distantPast }
            )
            let removedEvents = try dedupe(
                FetchDescriptor<RoutineEvent>(),
                in: context,
                id: \.id,
                rank: { $0.updatedAt ?? $0.startedAt ?? $0.createdAt ?? .distantPast }
            )

            let total = removedTasks + removedPlaces + removedLogs + removedSessions + removedAwaySessions + removedSleepSessions + removedPlaceCheckIns + removedEmotions + removedNotes + removedEvents
            guard total > 0 else { return }

            try context.save()
            print("RoutineDuplicateIDCleanup removed \(total) duplicate row(s): tasks=\(removedTasks) places=\(removedPlaces) logs=\(removedLogs) sessions=\(removedSessions) awaySessions=\(removedAwaySessions) sleepSessions=\(removedSleepSessions) placeCheckIns=\(removedPlaceCheckIns) emotions=\(removedEmotions) notes=\(removedNotes) events=\(removedEvents)")
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
    private static func mergeOverlappingSleepSessions(in context: ModelContext) throws -> Int {
        let intervals = try context.fetch(FetchDescriptor<SleepSession>())
            .compactMap(SleepSessionMergeInterval.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                if lhs.comparisonEndedAt != rhs.comparisonEndedAt {
                    return lhs.comparisonEndedAt > rhs.comparisonEndedAt
                }
                return lhs.session.id.uuidString < rhs.session.id.uuidString
            }

        var groups: [[SleepSessionMergeInterval]] = []
        var currentGroup: [SleepSessionMergeInterval] = []
        var currentEnd: Date?

        for interval in intervals {
            guard let end = currentEnd else {
                currentGroup = [interval]
                currentEnd = interval.comparisonEndedAt
                continue
            }

            if interval.startedAt < end {
                currentGroup.append(interval)
                currentEnd = max(end, interval.comparisonEndedAt)
            } else {
                groups.append(currentGroup)
                currentGroup = [interval]
                currentEnd = interval.comparisonEndedAt
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        var removed = 0
        for group in groups where group.count > 1 {
            let keeperInterval = group[0]
            let keeper = keeperInterval.session
            let losers = group.dropFirst().map(\.session)
            let loserIDs = Set(losers.map(\.id))
            let mergedStart = group.map(\.startedAt).min() ?? keeper.startedAt
            let mergedEnd = group.contains { $0.session.endedAt == nil }
                ? nil
                : group.compactMap(\.session.endedAt).max()

            keeper.startedAt = mergedStart
            keeper.endedAt = mergedEnd
            keeper.targetDurationMinutes = max(keeper.targetDurationMinutes, group.map(\.session.targetDurationMinutes).max() ?? keeper.targetDurationMinutes)
            keeper.createdAt = group.compactMap(\.session.createdAt).min() ?? keeper.createdAt
            keeper.updatedAt = group.compactMap { interval in
                interval.session.updatedAt ?? interval.session.endedAt ?? interval.session.startedAt
            }.max() ?? keeper.updatedAt

            try redirectEmotionSleepLinks(from: loserIDs, to: keeper.id, in: context)

            for loser in losers {
                context.delete(loser)
                removed += 1
            }
        }

        return removed
    }

    @MainActor
    private static func redirectEmotionSleepLinks(
        from removedSleepSessionIDs: Set<UUID>,
        to keeperSleepSessionID: UUID,
        in context: ModelContext
    ) throws {
        guard !removedSleepSessionIDs.isEmpty else { return }
        let emotions = try context.fetch(FetchDescriptor<EmotionLog>())
        for emotion in emotions where emotion.linkedSleepSessionID.map(removedSleepSessionIDs.contains) == true {
            emotion.linkedSleepSessionID = keeperSleepSessionID
        }
    }

    private struct SleepSessionMergeInterval {
        var session: SleepSession
        var startedAt: Date
        var comparisonEndedAt: Date

        init?(session: SleepSession) {
            guard let startedAt = session.startedAt else { return nil }
            let comparisonEndedAt = session.endedAt ?? .distantFuture
            guard comparisonEndedAt > startedAt else { return nil }
            self.session = session
            self.startedAt = startedAt
            self.comparisonEndedAt = comparisonEndedAt
        }
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
