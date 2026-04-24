import Foundation

enum HomeDisplayFilterSupport {
    static func tagSummaries<T>(
        from items: [T],
        tags: (T) -> [String]
    ) -> [RoutineTagSummary] {
        let tagCounts = items.reduce(into: [String: Int]()) { partialResult, item in
            for tag in tags(item) {
                guard let normalizedTag = RoutineTag.normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        return RoutineTag.allTags(from: items.map(tags))
            .map { tag in
                RoutineTagSummary(
                    name: tag,
                    linkedRoutineCount: tagCounts[RoutineTag.normalized(tag) ?? tag, default: 0]
                )
            }
            .sorted { lhs, rhs in
                if lhs.linkedRoutineCount != rhs.linkedRoutineCount {
                    return lhs.linkedRoutineCount > rhs.linkedRoutineCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        guard let selectedTag else { return true }
        return RoutineTag.contains(selectedTag, in: tags)
    }

    static func matchesExcludedTags(_ excludedTags: Set<String>, in tags: [String]) -> Bool {
        guard !excludedTags.isEmpty else { return true }
        return !excludedTags.contains { RoutineTag.contains($0, in: tags) }
    }

    static func matchesImportanceUrgencyFilter(
        _ selectedFilter: ImportanceUrgencyFilterCell?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> Bool {
        guard let selectedFilter else { return true }
        return selectedFilter.matches(importance: importance, urgency: urgency)
    }

    static func matchesTodoStateFilter(
        _ filter: TodoState?,
        isOneOffTask: Bool,
        todoState: TodoState?
    ) -> Bool {
        guard let filter else { return true }
        guard isOneOffTask else { return true }
        return todoState == filter
    }

    static func hasActiveRelationshipBlocker(
        taskID: UUID,
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }

        var blockerIDs = Set(
            task.relationships
                .filter { $0.kind == .blockedBy }
                .map(\.targetTaskID)
        )

        for candidate in tasks where candidate.id != taskID {
            if candidate.relationships.contains(where: { $0.targetTaskID == taskID && $0.kind == .blocks }) {
                blockerIDs.insert(candidate.id)
            }
        }

        return tasks.contains { candidate in
            guard blockerIDs.contains(candidate.id) else { return false }
            let status = RoutineTaskRelationshipStatus.resolved(
                for: candidate,
                referenceDate: referenceDate,
                calendar: calendar
            )
            return status != .doneToday
                && status != .completedOneOff
                && status != .canceledOneOff
        }
    }

    static func validateTaskFilters<T>(
        taskFilters: inout HomeTaskFiltersState,
        routineDisplays: [T],
        awayRoutineDisplays: [T],
        archivedRoutineDisplays: [T],
        routinePlaces: [RoutinePlace],
        tags: (T) -> [String]
    ) {
        let allDisplays = routineDisplays + awayRoutineDisplays + archivedRoutineDisplays
        let allAvailableTags = tagSummaries(from: allDisplays, tags: tags).map(\.name)
        if let tag = taskFilters.selectedTag, !RoutineTag.contains(tag, in: allAvailableTags) {
            taskFilters.selectedTag = nil
        }

        let includeScopedDisplays = allDisplays.filter {
            matchesSelectedTag(taskFilters.selectedTag, in: tags($0))
        }
        let availableExcludeTags = tagSummaries(from: includeScopedDisplays, tags: tags)
            .map(\.name)
            .filter { tag in
                taskFilters.selectedTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
            }
        taskFilters.excludedTags = taskFilters.excludedTags.filter {
            RoutineTag.contains($0, in: availableExcludeTags)
        }

        if let placeID = taskFilters.selectedManualPlaceFilterID,
           !routinePlaces.contains(where: { $0.id == placeID }) {
            taskFilters.selectedManualPlaceFilterID = nil
        }
    }
}
