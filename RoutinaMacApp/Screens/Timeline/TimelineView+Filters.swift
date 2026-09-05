import ComposableArchitecture
import SwiftUI

extension TimelineView {
    var filterSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.setFilterSheet($0)) }
        )
    }

    private var selectedRangeBinding: Binding<TimelineRange> {
        Binding(
            get: { store.selectedRange },
            set: { store.send(.selectedRangeChanged($0)) }
        )
    }

    var filterTypeBinding: Binding<TimelineFilterType> {
        Binding(
            get: { effectiveFilterType },
            set: {
                store.send(
                    .filterTypeChanged(
                        $0.normalized(
                            includingEventEmotion: areMacEventEmotionActionsEnabled,
                            includingPlaces: isPlacesEnabled,
                            includingNotes: isNotesEnabled,
                            includingAway: isAwayEnabled,
                            includingSleep: includesSleepTimelineFilters
                        )
                    ))
            }
        )
    }

    private var mediaFilterBinding: Binding<TaskMediaFilter> {
        Binding(
            get: { store.mediaFilter },
            set: { store.send(.mediaFilterChanged($0)) }
        )
    }

    var groupedByDay: [TimelineFeature.TimelineSection] {
        store.groupedEntries
    }

    private var latestTimelineEntryID: UUID? {
        groupedByDay.first?.entries.first?.id
    }

    private var availableTags: [String] {
        store.availableTags
    }

    private var filterPresentation: TimelineFilterPresentation {
        TimelineFilterPresentation(
            selectedTags: store.effectiveSelectedTags,
            excludedTags: store.excludedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            availableTags: availableTags,
            relatedTagRules: store.relatedTagRules
        )
    }

    private var suggestedRelatedFilterTags: [String] {
        filterPresentation.suggestedRelatedTags(suggestionAnchor: relatedFilterTagSuggestionAnchor)
    }

    private var availableExcludeTags: [String] {
        filterPresentation.availableExcludeTags()
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        filterPresentation.isIncludedTagSelected(tag)
    }

    private func toggleIncludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledIncludedTag(
            tag,
            currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
        )
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func addIncludedTag(_ tag: String) {
        guard
            let mutation = filterPresentation.addedIncludedTag(
                tag,
                currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
            )
        else { return }
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func toggleExcludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledExcludedTag(tag)
        store.send(.selectedTagsChanged(mutation.selectedTags))
        store.send(.excludedTagsChanged(mutation.excludedTags))
    }

    var filterSheetButton: some View {
        Button {
            store.send(.setFilterSheet(true))
        } label: {
            Image(
                systemName: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    var timelineFiltersSheet: some View {
        NavigationStack {
            List {
                Section("Range") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Range",
                        options: TimelineRange.allCases,
                        selection: selectedRangeBinding
                    ) { range in
                        Text(range.rawValue)
                    }
                }

                if showsTypeFilterSection {
                    Section("Type") {
                        RoutinaGlassSegmentedControl(
                            accessibilityLabel: "Type",
                            options: TimelineFilterType.visibleCases(
                                includingEventEmotion: areMacEventEmotionActionsEnabled,
                                includingPlaces: isPlacesEnabled,
                                includingNotes: isNotesEnabled,
                                includingAway: isAwayEnabled,
                                includingSleep: includesSleepTimelineFilters
                            ),
                            selection: filterTypeBinding
                        ) { type in
                            Text(type.title)
                        }
                    }
                }

                Section("Media") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Media",
                        options: TaskMediaFilter.allCases,
                        selection: mediaFilterBinding,
                        minimumSegmentWidth: 92
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }

                if !availableTags.isEmpty {
                    Section("Tag Rules") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Show items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                RoutinaGlassSegmentedControl(
                                    accessibilityLabel: "Show items with",
                                    options: RoutineTagMatchMode.allCases,
                                    selection: Binding(
                                        get: { store.includeTagMatchMode },
                                        set: { store.send(.includeTagMatchModeChanged($0)) }
                                    ),
                                    fillsAvailableWidth: true
                                ) { mode in
                                    Text(mode.rawValue)
                                }
                                .frame(maxWidth: 180)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if store.effectiveSelectedTags.isEmpty {
                                        timelineTagButton(title: "All Tags", isSelected: true) {
                                            relatedFilterTagSuggestionAnchor = nil
                                            store.send(.selectedTagsChanged([]))
                                        }
                                    } else {
                                        ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: true) {
                                                toggleIncludedTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !suggestedRelatedFilterTags.isEmpty {
                                Text("Suggested")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestedRelatedFilterTags, id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: false) {
                                                addIncludedTag(tag)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }

                            Text("Add more")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableTags.filter { !isIncludedTagSelected($0) }, id: \.self) { tag in
                                        timelineTagButton(title: "#\(tag)", isSelected: false) {
                                            toggleIncludedTag(tag)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Hide items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                RoutinaGlassSegmentedControl(
                                    accessibilityLabel: "Hide items with",
                                    options: RoutineTagMatchMode.allCases,
                                    selection: Binding(
                                        get: { store.excludeTagMatchMode },
                                        set: { store.send(.excludeTagMatchModeChanged($0)) }
                                    ),
                                    fillsAvailableWidth: true
                                ) { mode in
                                    Text(mode.rawValue)
                                }
                                .frame(maxWidth: 180)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if store.excludedTags.isEmpty {
                                        Text("No hidden tags")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: true, selectedColor: .red) {
                                                toggleExcludedTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !availableExcludeTags.isEmpty {
                                Text("Add tags to hide")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(
                                            availableExcludeTags.filter { tag in
                                                !store.excludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                            }, id: \.self
                                        ) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: false, selectedColor: .red) {
                                                toggleExcludedTag(tag)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                if hasActiveFilters {
                    Section {
                        Button("Clear Filters") {
                            store.send(.clearFilters)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        store.send(.setFilterSheet(false))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            store.send(.selectedTagsChanged(store.effectiveSelectedTags.filter { RoutineTag.contains($0, in: newValue) }))
        }
    }

    private func timelineTagButton(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .routinaGlassPill(
                    tint: isSelected ? selectedColor : .secondary,
                    tintOpacity: isSelected ? 0.16 : 0.10,
                    interactive: true
                )
                .foregroundStyle(isSelected ? selectedColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
