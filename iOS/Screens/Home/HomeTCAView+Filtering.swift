import SwiftUI
import ComposableArchitecture
import Foundation

extension HomeTCAView {
    var pinnedManualOrderSectionKey: String { "pinned" }
    var archivedManualOrderSectionKey: String { "archived" }

    func regularManualOrderSectionKey(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isDoneToday {
            return "doneToday"
        }
        if overdueDays(for: task) > 0 {
            return "overdue"
        }
        if urgencyLevel(for: task) > 0 || isYellowUrgency(task) {
            return "dueSoon"
        }

        switch routineListSectioningMode {
        case .status:
            return "onTrack"
        case .deadlineDate:
            guard let sectionDate = sectionDateForDeadlineGrouping(for: task) else {
                return "onTrack"
            }
            return "onTrack:\(manualOrderDateKey(for: sectionDate))"
        }
    }

    private func manualOrderDateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func filteredTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesCurrentTaskListMode(task)
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesTaskListViewMode(task)
                && matchesManualPlaceFilter(task)
                && matchesTodoStateFilter(task)
                && HomeFeature.matchesImportanceUrgencyFilter(store.selectedImportanceUrgencyFilter, importance: task.importance, urgency: task.urgency)
                && HomeFeature.matchesSelectedTags(store.selectedTags, mode: store.includeTagMatchMode, in: task.tags)
                && HomeFeature.matchesExcludedTags(store.excludedTags, mode: store.excludeTagMatchMode, in: task.tags)
        }
    }

    func filteredAwayTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesCurrentTaskListMode(task)
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesTaskListViewMode(task)
                && matchesManualPlaceFilter(task)
                && matchesTodoStateFilter(task)
                && HomeFeature.matchesImportanceUrgencyFilter(store.selectedImportanceUrgencyFilter, importance: task.importance, urgency: task.urgency)
                && HomeFeature.matchesSelectedTags(store.selectedTags, mode: store.includeTagMatchMode, in: task.tags)
                && HomeFeature.matchesExcludedTags(store.excludedTags, mode: store.excludeTagMatchMode, in: task.tags)
        }
    }

    func filteredArchivedTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay],
        includePinned: Bool = true
    ) -> [HomeFeature.RoutineDisplay] {
        routineDisplays
            .filter { task in
                matchesCurrentTaskListMode(task)
                    && !task.isCompletedOneOff
                    && !task.isCanceledOneOff
                    && (includePinned || !task.isPinned)
                    && matchesTaskListViewMode(task)
                    && matchesSearch(task)
                    && matchesManualPlaceFilter(task)
                    && matchesTodoStateFilter(task)
                    && HomeFeature.matchesImportanceUrgencyFilter(store.selectedImportanceUrgencyFilter, importance: task.importance, urgency: task.urgency)
                    && HomeFeature.matchesSelectedTags(store.selectedTags, mode: store.includeTagMatchMode, in: task.tags)
                    && HomeFeature.matchesExcludedTags(store.excludedTags, mode: store.excludeTagMatchMode, in: task.tags)
            }
            .sorted(by: archivedTaskSort)
    }

    func filteredPinnedTasks(
        activeRoutineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        let activePinned = sortedTasks(activeRoutineDisplays + awayRoutineDisplays).filter { task in
            task.isPinned
                && matchesCurrentTaskListMode(task)
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesTaskListViewMode(task)
                && matchesManualPlaceFilter(task)
                && matchesTodoStateFilter(task)
                && HomeFeature.matchesImportanceUrgencyFilter(store.selectedImportanceUrgencyFilter, importance: task.importance, urgency: task.urgency)
                && HomeFeature.matchesSelectedTags(store.selectedTags, mode: store.includeTagMatchMode, in: task.tags)
                && HomeFeature.matchesExcludedTags(store.excludedTags, mode: store.excludeTagMatchMode, in: task.tags)
        }
        let archivedPinned = filteredArchivedTasks(archivedRoutineDisplays).filter(\.isPinned)

        return (activePinned + archivedPinned).sorted(by: pinnedTaskSort)
    }

    func matchesSearch(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let trimmedSearch = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return task.name.localizedCaseInsensitiveContains(trimmedSearch)
            || task.emoji.localizedCaseInsensitiveContains(trimmedSearch)
            || (task.notes?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || (task.placeName?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || RoutineTag.matchesQuery(trimmedSearch, in: task.tags)
    }

    func matchesFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch store.selectedFilter {
        case .all:
            return true
        case .due:
            return !task.isDoneToday && (urgencyLevel(for: task) > 0 || isYellowUrgency(task))
        case .todos:
            return task.isOneOffTask
        case .doneToday:
            return task.isDoneToday
        }
    }

    func matchesManualPlaceFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        guard let selectedManualPlaceFilterID = store.selectedManualPlaceFilterID else { return true }
        return task.placeID == selectedManualPlaceFilterID
    }

    func matchesTodoStateFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        HomeFeature.matchesTodoStateFilter(store.selectedTodoStateFilter, task: task)
    }

    func matchesTaskListViewMode(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch store.taskListViewMode {
        case .all:
            return true
        case .actionable:
            return !HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
                taskID: task.taskID,
                tasks: store.routineTasks,
                referenceDate: Date(),
                calendar: calendar
            )
        }
    }

    func groupedRoutineSections(
        from routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [RoutineListSection] {
        let filtered = filteredTasks(routineDisplays)

        let overdue = filtered.filter { overdueDays(for: $0) > 0 }
        let dueSoon = filtered.filter {
            !($0.isDoneToday) &&
            overdueDays(for: $0) == 0 &&
            (urgencyLevel(for: $0) > 0 || isYellowUrgency($0))
        }
        let onTrack = filtered.filter {
            !($0.isDoneToday) &&
            overdueDays(for: $0) == 0 &&
            urgencyLevel(for: $0) == 0 &&
            !isYellowUrgency($0)
        }
        let doneToday = filtered.filter(\.isDoneToday)

        let onTrackSections: [RoutineListSection]
        switch routineListSectioningMode {
        case .status:
            onTrackSections = [RoutineListSection(title: "On Track", tasks: onTrack)]
        case .deadlineDate:
            onTrackSections = deadlineBasedSections(from: onTrack)
        }

        return (
            [
            RoutineListSection(title: "Overdue", tasks: overdue),
                RoutineListSection(title: "Due Soon", tasks: dueSoon)
            ]
            + onTrackSections
            + [RoutineListSection(title: "Done Today", tasks: doneToday)]
        )
        .filter { !$0.tasks.isEmpty }
    }

    func deadlineBasedSections(
        from tasks: [HomeFeature.RoutineDisplay]
    ) -> [RoutineListSection] {
        guard !tasks.isEmpty else { return [] }

        let sorted = tasks.sorted { lhs, rhs in
            let lhsDate = sectionDateForDeadlineGrouping(for: lhs) ?? .distantFuture
            let rhsDate = sectionDateForDeadlineGrouping(for: rhs) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return regularTaskSort(lhs, rhs)
        }

        var sections: [RoutineListSection] = []
        for task in sorted {
            let title = deadlineSectionTitle(for: task)
            if let lastIndex = sections.indices.last, sections[lastIndex].title == title {
                sections[lastIndex].tasks.append(task)
            } else {
                sections.append(RoutineListSection(title: title, tasks: [task]))
            }
        }

        return sections
    }

    func sectionDateForDeadlineGrouping(
        for task: HomeFeature.RoutineDisplay
    ) -> Date? {
        guard task.daysUntilDue != Int.max else { return nil }
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: max(task.daysUntilDue, 0), to: today)
            .map { calendar.startOfDay(for: $0) }
    }

    func deadlineSectionTitle(for task: HomeFeature.RoutineDisplay) -> String {
        guard let sectionDate = sectionDateForDeadlineGrouping(for: task) else {
            return "On Track"
        }
        return formattedDeadlineSectionTitle(for: sectionDate)
    }

    func formattedDeadlineSectionTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        let includesYear = calendar.component(.year, from: date) != calendar.component(.year, from: Date())
        formatter.setLocalizedDateFormatFromTemplate(includesYear ? "EEE MMM d yyyy" : "EEE MMM d")
        return formatter.string(from: date)
    }

    func isYellowUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        if task.isOneOffTask {
            return false
        }
        if task.isInProgress
            || task.scheduleMode == .derivedFromChecklist
            || (task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0) {
            return false
        }
        if task.recurrenceRule.isFixedCalendar {
            return dueInDays(for: task) == 1
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    func dueInDays(for task: HomeFeature.RoutineDisplay) -> Int {
        task.daysUntilDue
    }

    func overdueDays(for task: HomeFeature.RoutineDisplay) -> Int {
        max(-dueInDays(for: task), 0)
    }

    func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(from: task.lastDone, referenceDate: Date())
    }

    func daysSinceScheduleAnchor(_ task: HomeFeature.RoutineDisplay) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(
            from: task.scheduleAnchor ?? task.lastDone,
            referenceDate: Date()
        )
    }

    func urgencyColor(for task: HomeFeature.RoutineDisplay) -> Color {
        if task.isPaused {
            return .teal
        }
        if case .away = task.locationAvailability {
            return .blue
        }
        if task.isInProgress {
            return .orange
        }
        if task.isOneOffTask {
            return task.isCompletedOneOff ? .green : (task.isCanceledOneOff ? .orange : .blue)
        }
        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return .orange
        }
        if task.recurrenceRule.isFixedCalendar {
            let urgency = urgencyLevel(for: task)
            switch urgency {
            case 3:
                return .red
            case 2, 1:
                return .orange
            default:
                return .green
            }
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    func rowIconBackgroundColor(for task: HomeFeature.RoutineDisplay) -> Color {
        urgencyColor(for: task).opacity(task.isDoneToday ? 0.22 : 0.14)
    }
}
