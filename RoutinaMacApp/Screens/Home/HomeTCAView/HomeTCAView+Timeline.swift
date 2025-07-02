import SwiftUI

extension HomeTCAView {
    var timelineEntries: [TimelineEntry] {
        baseTimelineEntries
            .filter { entry in
                HomeFeature.matchesImportanceUrgencyFilter(
                    store.selectedTimelineImportanceUrgencyFilter,
                    importance: entry.importance,
                    urgency: entry.urgency
                )
                    && TimelineLogic.matchesSelectedTag(store.selectedTimelineTag, in: entry.tags)
                    && !store.selectedTimelineExcludedTags.contains { RoutineTag.contains($0, in: entry.tags) }
            }
            .filter(matchesTimelineSearch)
    }

    private var baseTimelineEntries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: store.timelineLogs,
            tasks: store.routineTasks,
            range: store.selectedTimelineRange,
            filterType: store.selectedTimelineFilterType,
            now: Date(),
            calendar: calendar
        )
    }

    var availableTimelineTags: [String] {
        TimelineLogic.availableTags(
            from: filteredTimelineEntriesForTagging
        )
    }

    private var filteredTimelineEntriesForTagging: [TimelineEntry] {
        baseTimelineEntries.filter { entry in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedTimelineImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }
    }

    var availableTimelineExcludeTags: [String] {
        availableTimelineTags.filter { tag in
            store.selectedTimelineTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
    }

    var groupedTimelineEntries: [(date: Date, entries: [TimelineEntry])] {
        TimelineLogic.groupedByDay(entries: timelineEntries, calendar: calendar)
    }

    private func openTimelineEntry(_ entry: TimelineEntry) {
        store.send(.macSidebarSelectionChanged(.timelineEntry(entry.id)))
        store.send(.setSelectedTask(entry.taskID))
    }

    func openTimelineInSidebar() {
        store.send(.macSidebarModeChanged(.timeline))
        validateSelectedTimelineTag()
    }

    func timelineSidebarRow(_ entry: TimelineEntry, rowNumber: Int) -> some View {
        Button {
            openTimelineEntry(entry)
        } label: {
            HStack(spacing: 12) {
                Text("\(rowNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, alignment: .trailing)

                Text(entry.taskEmoji)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(entry.isOneOff ? "Todo" : "Routine")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(entry.isOneOff ? Color.purple.opacity(0.15) : Color.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(entry.isOneOff ? .purple : .accentColor)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tag(HomeFeature.MacSidebarSelection.timelineEntry(entry.id))
        .contentShape(Rectangle())
    }

    private func matchesTimelineSearch(_ entry: TimelineEntry) -> Bool {
        let trimmedSearch = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return entry.taskName.localizedCaseInsensitiveContains(trimmedSearch)
            || entry.taskEmoji.localizedCaseInsensitiveContains(trimmedSearch)
            || (entry.isOneOff
                ? "todo".localizedCaseInsensitiveContains(trimmedSearch)
                : "routine".localizedCaseInsensitiveContains(trimmedSearch))
    }

    func validateSelectedTimelineTag() {
        guard let tag = store.selectedTimelineTag else { return }
        if !RoutineTag.contains(tag, in: availableTimelineTags) {
            store.send(.selectedTimelineTagChanged(nil))
        }
        store.send(
            .selectedTimelineExcludedTagsChanged(
                store.selectedTimelineExcludedTags.filter { RoutineTag.contains($0, in: availableTimelineExcludeTags) }
            )
        )
    }

    var timelineImportanceUrgencySummary: String {
        guard let filter = store.selectedTimelineImportanceUrgencyFilter else {
            return "Choose a cell to show done items from tasks that meet or exceed that importance and urgency."
        }
        return "Showing done items from tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    var timelineTagSelectionSummary: String {
        if let selectedTimelineTag = store.selectedTimelineTag {
            let matchingCount = timelineTagCount(for: selectedTimelineTag)
            return "#\(selectedTimelineTag) across \(matchingCount) \(matchingCount == 1 ? "item" : "items")"
        }

        let tagCount = availableTimelineTags.count
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }

    var timelineExcludedTagSummary: String {
        if !store.selectedTimelineExcludedTags.isEmpty {
            return "Hiding items tagged: \(store.selectedTimelineExcludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        return "Select tags to hide done items that have them."
    }

    var macActiveTimelineFiltersSummary: String? {
        var labels: [String] = []

        if store.selectedTimelineRange != .all {
            labels.append(store.selectedTimelineRange.rawValue)
        }

        if store.selectedTimelineFilterType != .all {
            labels.append(store.selectedTimelineFilterType.rawValue)
        }

        if let filter = store.selectedTimelineImportanceUrgencyFilter {
            labels.append("\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+")
        }

        if let selectedTag = store.selectedTimelineTag {
            labels.append("#\(selectedTag)")
        }

        if !store.selectedTimelineExcludedTags.isEmpty {
            if store.selectedTimelineExcludedTags.count == 1, let tag = store.selectedTimelineExcludedTags.first {
                labels.append("not #\(tag)")
            } else {
                labels.append("not \(store.selectedTimelineExcludedTags.count) tags")
            }
        }

        let summary = summarizedFilterLabels(from: labels, maxVisibleCount: 4)
        return summary.isEmpty ? nil : summary
    }

    private func timelineTagCount(for tag: String) -> Int {
        filteredTimelineEntriesForTagging.filter { entry in
            RoutineTag.contains(tag, in: entry.tags)
        }.count
    }

    var macTimelineFiltersDetailView: some View {
        HomeMacTimelineFilterDetailContainerView(
            onAvailableTagsChange: { validateSelectedTimelineTag() },
            availableTags: availableTimelineTags
        ) {
            HomeMacTimelineFiltersDetailView(
                selectedRange: Binding(
                    get: { store.selectedTimelineRange },
                    set: { store.send(.selectedTimelineRangeChanged($0)) }
                ),
                selectedType: Binding(
                    get: { store.selectedTimelineFilterType },
                    set: { store.send(.selectedTimelineFilterTypeChanged($0)) }
                ),
                selectedImportanceUrgencyFilter: Binding(
                    get: { store.selectedTimelineImportanceUrgencyFilter },
                    set: { store.send(.selectedTimelineImportanceUrgencyFilterChanged($0)) }
                ),
                showsTypeSection: store.routineTasks.contains(where: \.isOneOffTask),
                importanceUrgencySummary: timelineImportanceUrgencySummary,
                allTagsCount: filteredTimelineEntriesForTagging.count,
                availableTags: availableTimelineTags,
                availableExcludeTags: availableTimelineExcludeTags,
                selectedTag: store.selectedTimelineTag,
                selectedExcludedTags: store.selectedTimelineExcludedTags,
                tagSelectionSummary: timelineTagSelectionSummary,
                excludedTagSummary: timelineExcludedTagSummary,
                tagCount: { tag in
                    timelineTagCount(for: tag)
                },
                onSelectTag: { tag in
                    store.send(.selectedTimelineTagChanged(tag))
                },
                onToggleExcludedTag: { tag in
                    if store.selectedTimelineExcludedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
                        store.send(.selectedTimelineExcludedTagsChanged(store.selectedTimelineExcludedTags.filter { $0 != tag }))
                    } else {
                        var newTags = store.selectedTimelineExcludedTags
                        newTags.insert(tag)
                        store.send(.selectedTimelineExcludedTagsChanged(newTags))
                        if store.selectedTimelineTag.map({ RoutineTag.contains($0, in: [tag]) }) == true {
                            store.send(.selectedTimelineTagChanged(nil))
                        }
                    }
                }
            )
        }
    }

    var macTimelineSidebarView: some View {
        HomeMacTimelineSidebarView(
            timelineLogCount: store.timelineLogs.count,
            groupedEntries: groupedTimelineEntries,
            selection: macSidebarSelectionBinding,
            sectionTitle: { date in
                TimelineLogic.daySectionTitle(for: date, calendar: calendar)
            }
        ) { entry, rowNumber in
            timelineSidebarRow(entry, rowNumber: rowNumber)
        }
    }
}
