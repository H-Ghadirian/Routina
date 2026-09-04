import SwiftUI

@MainActor
final class DayPlanTimelinePlacementCache: ObservableObject {
    private var cachedReuseSignature: DayPlanTimelinePlacementReuseSignature?
    private var cachedFastSignature: DayPlanTimelinePlacementFastSignature?
    private var cachedKey: DayPlanTimelinePlacementCacheKey?
    private var cachedPlacements: [String: DayPlanTimelineActivityPlacement] = [:]
    private var requiresFullValidation = false

    func automaticSuggestionPlacementsByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [String: DayPlanTimelineActivityPlacement] {
        let reuseSignature = DayPlanTimelinePlacementReuseSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )

        if !requiresFullValidation, cachedReuseSignature == reuseSignature, cachedKey != nil {
            return cachedPlacements
        }

        let fastSignature = DayPlanTimelinePlacementFastSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )

        if !requiresFullValidation, cachedFastSignature == fastSignature, cachedKey != nil {
            cachedReuseSignature = reuseSignature
            return cachedPlacements
        }

        let key = DayPlanTimelinePlacementCacheKey(
            dates: dates,
            tasks: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )

        if cachedKey == key {
            cachedReuseSignature = reuseSignature
            cachedFastSignature = fastSignature
            requiresFullValidation = false
            return cachedPlacements
        }

        let placements = DayPlanTimelineTasks.automaticSuggestionPlacementsByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )
        cachedReuseSignature = reuseSignature
        cachedFastSignature = fastSignature
        cachedKey = key
        cachedPlacements = placements
        requiresFullValidation = false
        return placements
    }

    func requireFullValidation() {
        requiresFullValidation = true
    }

    func invalidate() {
        cachedReuseSignature = nil
        cachedFastSignature = nil
        cachedKey = nil
        cachedPlacements = [:]
        requiresFullValidation = false
    }
}

private struct DayPlanTimelinePlacementReuseSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var referenceRenderBucket: DayPlanTimelineReferenceRenderBucket
    var visibleDayKeys: [String]
    var hiddenActivityIDs: [String]
    var taskObjects: [ObjectIdentifier]
    var logObjects: [ObjectIdentifier]
    var plannedDays: [DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot]
    var blockedDays: [DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String>,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceRenderBucket = DayPlanTimelineReferenceRenderBucket(
            dates: dates,
            calendar: calendar,
            referenceDate: referenceDate
        )
        visibleDayKeys =
            dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.hiddenActivityIDs = hiddenActivityIDs.sorted()
        taskObjects = tasks.map { ObjectIdentifier($0) }
        logObjects = logs.map { ObjectIdentifier($0) }
        plannedDays =
            plannedBlocksByDayKey
            .map { dayKey, blocks in
                DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot(dayKey: dayKey, blocks: blocks)
            }
            .sorted { $0.dayKey < $1.dayKey }
        blockedDays =
            blockedIntervalsByDayKey
            .map { dayKey, intervals in
                DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot(dayKey: dayKey, intervals: intervals)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }
}

private struct DayPlanTimelineReferenceRenderBucket: Equatable {
    var referenceDayKey: String
    var visibleCurrentMinute: Int?

    init(
        dates: [Date],
        calendar: Calendar,
        referenceDate: Date
    ) {
        referenceDayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard visibleDayKeys.contains(referenceDayKey) else {
            visibleCurrentMinute = nil
            return
        }

        let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
        visibleCurrentMinute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }
}

private struct DayPlanTimelinePlacementFastSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var referenceAssumptionBucket: DayPlanTimelineReferenceAssumptionBucket
    var visibleDayKeys: [String]
    var hiddenActivityIDs: Set<String>
    var taskIDs: Set<UUID>
    var logIDs: Set<UUID>
    var plannedDays: [DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot]
    var blockedDays: [DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String>,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceAssumptionBucket = DayPlanTimelineReferenceAssumptionBucket(
            dates: dates,
            tasks: tasks,
            calendar: calendar,
            referenceDate: referenceDate
        )
        visibleDayKeys =
            dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.hiddenActivityIDs = hiddenActivityIDs
        taskIDs = Set(tasks.map(\.id))
        logIDs = Set(logs.map(\.id))
        plannedDays =
            plannedBlocksByDayKey
            .map { dayKey, blocks in
                DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot(dayKey: dayKey, blocks: blocks)
            }
            .sorted { $0.dayKey < $1.dayKey }
        blockedDays =
            blockedIntervalsByDayKey
            .map { dayKey, intervals in
                DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot(dayKey: dayKey, intervals: intervals)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }
}
