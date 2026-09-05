import SwiftUI

extension HomeTCAView {
    func timelineSidebarRow(_ entry: TimelineEntry, rowNumber: Int) -> some View {
        let rowVisibility = timelineRowVisibility

        return Button {
            openTimelineEntry(entry)
        } label: {
            HStack(spacing: 12) {
                if rowVisibility.shows(.rowNumber) {
                    Text("\(rowNumber)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: sidebarRowNumberMinWidth, alignment: .trailing)
                }

                if rowVisibility.shows(.icon) {
                    Text(entry.taskEmoji)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .routinaScrollingRoundedFill(
                            cornerRadius: 8,
                            tint: .secondary,
                            tintOpacity: 0.06
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if rowVisibility.shows(.subtitle) {
                        Text(timelineSubtitle(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if rowVisibility.shows(.kindBadge) {
                    Text(timelineKindLabel(for: entry))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .routinaScrollingPillFill(
                            tint: timelineKindColor(for: entry),
                            tintOpacity: 0.15
                        )
                        .foregroundStyle(timelineKindColor(for: entry))
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tag(HomeFeature.MacSidebarSelection.timelineEntry(entry.id))
        .contentShape(Rectangle())
    }

    func matchesTimelineSearch(_ entry: TimelineEntry) -> Bool {
        let trimmedSearch = macSearchPresentationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return matchesTimelineSearch(entry, searchText: trimmedSearch)
    }

    func matchesTimelineSearch(_ entry: TimelineEntry, searchText: String) -> Bool {
        return entry.searchableText.localizedCaseInsensitiveContains(searchText)
            || timelineKindLabel(for: entry).localizedCaseInsensitiveContains(searchText)
    }

    func validateSelectedTimelineTag() {
        let selectedFlags = store.selectedTimelineFlags.filter {
            RoutineFlag.contains($0, in: availableTimelineFlags)
        }
        store.send(.selectedTimelineFlagsChanged(selectedFlags))
        let selected = store.selectedTimelineTags.filter {
            RoutineTag.contains($0, in: availableTimelineTags)
        }
        store.send(.selectedTimelineTagsChanged(selected))
        store.send(
            .selectedTimelineExcludedTagsChanged(
                store.selectedTimelineExcludedTags.filter {
                    RoutineTag.contains($0, in: availableTimelineExcludeTags)
                }
            )
        )
    }

    var macActiveTimelineFiltersSummary: String? {
        guard macHasActiveTimelineFilters else { return nil }

        var labels: [String] = []

        if effectiveMacTimelineFilterType != .all {
            labels.append(effectiveMacTimelineFilterType.title)
        }

        if store.selectedTimelineStatusFilter != .all {
            labels.append(store.selectedTimelineStatusFilter.title)
        }

        if let filter = store.selectedTimelineImportanceUrgencyFilter {
            if let importance = filter.minimumImportance {
                labels.append("Importance \(importance.title)+")
            }
            if let urgency = filter.minimumUrgency {
                labels.append("Urgency \(urgency.title)+")
            }
        }

        if let pressure = store.selectedTimelinePressureFilter {
            labels.append("Pressure \(pressure.title)+")
        }

        if let thinking = store.selectedTimelineThinkingNeededFilter {
            labels.append("Thinking \(thinking.title)")
        }

        if store.selectedTimelineEstimationFilter != .all {
            labels.append("Estimated time: \(store.selectedTimelineEstimationFilter.title)")
        }

        if store.selectedTimelineMediaFilter != .all {
            labels.append(store.selectedTimelineMediaFilter.title)
        }

        if !store.selectedTimelineTags.isEmpty {
            labels.append(
                "\(store.selectedTimelineIncludeTagMatchMode.rawValue) \(store.selectedTimelineTags.count) tags"
            )
        }

        if !macSharedSelectedFlags.isEmpty {
            labels.append("\(macSharedIncludeFlagMatchMode.rawValue) \(macSharedSelectedFlags.count) flags")
        }

        if !macSharedExcludedFlags.isEmpty {
            labels.append("not \(macSharedExcludedFlags.count) flags")
        }

        if !store.selectedTimelineExcludedTags.isEmpty {
            if let excludedTagsSummary = macTimelineExcludedTagsSummary {
                labels.append(excludedTagsSummary)
            }
        }

        let summary = summarizedFilterLabels(from: labels, maxVisibleCount: 4)
        return summaryWithResultCount(summary, resultCount: timelineEntries.count)
    }

    private var macTimelineExcludedTagsSummary: String? {
        let tags = store.selectedTimelineExcludedTags.sorted()
        guard !tags.isEmpty else { return nil }
        if tags.count == 1, let tag = tags.first {
            return "not #\(tag)"
        }
        if tags.count <= 6 {
            return "not \(tags.map { "#\($0)" }.joined(separator: ", "))"
        }

        let visibleTags = tags.prefix(4).map { "#\($0)" }.joined(separator: ", ")
        return "not \(visibleTags) +\(tags.count - 4) tags"
    }

    func matchesMacSharedTaskLadderFilters(_ entry: TimelineEntry) -> Bool {
        let hasActiveFilter =
            store.selectedTimelineImportanceUrgencyFilter != nil
            || store.selectedTimelinePressureFilter != nil
            || store.selectedTimelineThinkingNeededFilter != nil
            || store.selectedTimelineEstimationFilter != .all
        guard hasActiveFilter else { return true }
        guard entry.hasTaskLadderValues else { return false }

        return HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            store.selectedTimelineImportanceUrgencyFilter,
            importance: entry.currentImportance,
            urgency: entry.currentUrgency
        )
            && HomeDisplayFilterSupport.matchesMinimumPressureFilter(
                store.selectedTimelinePressureFilter,
                pressure: entry.currentPressure
            )
            && HomeDisplayFilterSupport.matchesThinkingNeededFilter(
                store.selectedTimelineThinkingNeededFilter,
                thinkingNeeded: entry.thinkingNeeded
            )
            && HomeDisplayFilterSupport.matchesEstimationFilter(
                store.selectedTimelineEstimationFilter,
                estimatedDurationMinutes: entry.estimatedDurationMinutes
            )
    }

    var macTimelineFiltersDetailView: some View {
        HomeMacFilterDetailContainerView(
            title: macFilterDetailTitle,
            showsTitle: false
        ) {
            macTimelineFiltersDetailContent
        }
    }

    var macTimelineFiltersDetailContent: some View {
        HomeMacTimelineFiltersDetailView(
            selectedType: Binding(
                get: { effectiveMacTimelineFilterType },
                set: {
                    store.send(
                        .selectedTimelineFilterTypeChanged(
                            $0.normalized(
                                includingEventEmotion: areMacEventEmotionActionsEnabled,
                                includingPlaces: isPlacesEnabled,
                                includingNotes: isNotesEnabled,
                                includingAway: isAwayEnabled,
                                includingSleep: includesMacSleepTimelineFilters
                            )
                        ))
                }
            ),
            selectedStatus: Binding(
                get: { store.selectedTimelineStatusFilter },
                set: { store.send(.selectedTimelineStatusFilterChanged($0)) }
            ),
            selectedMediaFilter: Binding(
                get: { store.selectedTimelineMediaFilter },
                set: { store.send(.selectedTimelineMediaFilterChanged($0)) }
            ),
            timelineRowVisibility: timelineRowVisibility,
            showsTypeSection: showsMacTimelineTypeFilterSection,
            onTimelineRowFieldVisibilityChanged: { field, isVisible in
                settingsStore.send(.timelineRowFieldVisibilityChanged(field, isVisible))
            },
            includesEventEmotionFilters: areMacEventEmotionActionsEnabled,
            includesPlaceFilters: isPlacesEnabled,
            includesNoteFilters: isNotesEnabled,
            includesAwayFilters: isAwayEnabled,
            includesSleepFilters: includesMacSleepTimelineFilters
        )
    }

    private var showsMacTimelineTypeFilterSection: Bool {
        timelineSourceTasks.contains(where: \.isOneOffTask)
            || (areMacEventEmotionActionsEnabled && (!events.isEmpty || !emotionLogs.isEmpty))
            || (isNotesEnabled && !notes.isEmpty)
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || (includesMacSleepTimelineFilters && !sleepSessions.isEmpty)
            || (isAwayEnabled && !awaySessions.isEmpty)
            || (isPlacesEnabled && !placeCheckInSessions.isEmpty)
    }

    private var macTimelineSidebarEntryCount: Int {
        timelineSourceLogs.count
            + (areMacEventEmotionActionsEnabled ? events.count + emotionLogs.count : 0)
            + (isNotesEnabled ? notes.count : 0)
            + focusSessions.count
            + sprintFocusSessions.count
            + (includesMacSleepTimelineFilters ? sleepSessions.count : 0)
            + (isAwayEnabled ? awaySessions.count : 0)
            + (isPlacesEnabled ? placeCheckInSessions.count : 0)
    }

    func macPlannerTimelineListView(dateJumpRequest: DayPlanTimelineDateJumpRequest?) -> some View {
        HomeMacPlannerTimelineListView(
            timelineEntryCount: plannerTimelineEntryCount,
            groupedEntries: groupedPlannerTimelineEntries,
            rowNumbersByEntryID: macTimelineRowNumbersByEntryID,
            activeFiltersTitle: macPlannerTimelineFilterNoticeTitle,
            activeFiltersSummary: macActiveTimelineFiltersSummary,
            showsPlaces: isPlacesEnabled,
            showsNotes: isNotesEnabled,
            showsAway: isAwayEnabled,
            dateJumpRequest: dateJumpRequest,
            calendar: calendar,
            sectionTitle: { date in
                TimelineLogic.daySectionTitle(for: date, calendar: calendar)
            },
            onClearFilters: {
                clearAllMacTimelineFilters()
            },
            rowContent: { entry, rowNumber in
                plannerTimelineRow(entry, rowNumber: rowNumber)
            }
        )
    }

    var macTimelineSidebarView: some View {
        VStack(spacing: 0) {
            if areMacTimelineQuickFiltersVisible {
                TimelinePigmentControl(
                    selection: Binding(
                        get: { effectiveMacTimelineFilterType },
                        set: {
                            store.send(
                                .selectedTimelineFilterTypeChanged(
                                    $0.normalized(
                                        includingEventEmotion: areMacEventEmotionActionsEnabled,
                                        includingPlaces: isPlacesEnabled,
                                        includingNotes: isNotesEnabled,
                                        includingAway: isAwayEnabled,
                                        includingSleep: includesMacSleepTimelineFilters
                                    )
                                ))
                        }
                    ),
                    includesEventEmotion: areMacEventEmotionActionsEnabled,
                    includesPlaces: isPlacesEnabled,
                    includesNotes: isNotesEnabled,
                    includesAway: isAwayEnabled,
                    includesSleep: includesMacSleepTimelineFilters
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            HomeMacTimelineSidebarView(
                timelineEntryCount: macTimelineSidebarEntryCount,
                groupedEntries: groupedTimelineEntries,
                rowNumbersByEntryID: macTimelineRowNumbersByEntryID,
                presentationID: macTimelineSidebarPresentationID,
                isActive: isMacTimelineMode,
                allowsFallbackSelection: !store.isMacFilterDetailPresented,
                showsPlaces: isPlacesEnabled,
                showsNotes: isNotesEnabled,
                showsAway: isAwayEnabled,
                positionedPresentationID: $macTimelineSidebarPositionedPresentationID,
                selection: macSidebarSelectionBinding,
                scrollRequest: $macTimelineSidebarScrollRequest,
                sectionTitle: { date in
                    TimelineLogic.daySectionTitle(for: date, calendar: calendar)
                },
                rowContent: { entry, rowNumber in
                    timelineSidebarRow(entry, rowNumber: rowNumber)
                }
            )
        }
    }

    func plannerTimelineRow(_ entry: TimelineEntry, rowNumber: Int) -> some View {
        let rowVisibility = timelineRowVisibility

        return Button {
            openPlannerTimelineEntry(entry)
        } label: {
            HStack(spacing: 14) {
                if rowVisibility.shows(.rowNumber) {
                    Text("\(rowNumber)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: sidebarRowNumberMinWidth, alignment: .trailing)
                }

                if rowVisibility.shows(.icon) {
                    Text(entry.taskEmoji)
                        .font(.title2)
                        .frame(width: 38, height: 38)
                        .routinaScrollingRoundedFill(
                            cornerRadius: 8,
                            tint: .secondary,
                            tintOpacity: 0.06
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if rowVisibility.shows(.subtitle) {
                        Text(timelineSubtitle(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if rowVisibility.shows(.kindBadge) {
                    Text(timelineKindLabel(for: entry))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .routinaScrollingPillFill(
                            tint: timelineKindColor(for: entry),
                            tintOpacity: 0.15
                        )
                        .foregroundStyle(timelineKindColor(for: entry))
                }
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var noteAttachmentNoteIDs: Set<UUID> {
        Set(noteAttachments.map(\.noteID))
    }
}
