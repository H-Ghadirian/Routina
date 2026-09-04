import ComposableArchitecture
import SwiftUI

struct BacklogMacFiltersDetailView: View {
    @State private var selectedTab: HomeMacFilterDetailTab = .filter
    @AppStorage(
        UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var backlogTaskRowHiddenFieldsRawValue = HomeTaskRowVisibility.backlogDefaultStorageRawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

    let store: StoreOf<BacklogFeature>

    var body: some View {
        HomeMacFilterDetailContainerView(
            title: "Backlog Controls",
            showsTitle: false
        ) {
            HomeMacFilterDetailTabStrip(
                selection: $selectedTab,
                accessibilityLabel: "Backlog tabs"
            )
            sectionControls

            switch selectedTab {
            case .filter:
                filterTabContent
            case .sort:
                sortTabContent
            case .appearance:
                appearanceTabContent
            }
        }
    }

    private var sectionControls: some View {
        HStack(spacing: 10) {
            Text(backlogCountLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                store.send(.refresh)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Refresh Backlog")
            .disabled(store.isLoading)

            Spacer(minLength: 8)

            Button(resetButtonTitle) {
                resetSelectedSection()
            }
            .disabled(!canResetSelectedSection)
        }
    }

    private var filterTabContent: some View {
        Group {
            coreFilters
            taskLadderFilters
            tagFilters
            flagFilters
        }
    }

    private var coreFilters: some View {
        HomeMacSidebarSectionCard(title: "Filters") {
            VStack(alignment: .leading, spacing: 18) {
                HomeMacAdaptiveFilterControlRow("Task type") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog task type",
                        options: HomeTaskListMode.allCases,
                        selection: filterBinding(\.taskListMode),
                        minimumSegmentWidth: 112,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                }

                HomeMacAdaptiveFilterControlRow("Created") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog created date",
                        options: HomeTaskCreatedDateFilter.allCases,
                        selection: filterBinding(\.createdDateFilter),
                        minimumSegmentWidth: 126,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }

                HomeMacAdaptiveFilterControlRow("Due") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog due date",
                        options: BacklogDueDateFilter.allCases,
                        selection: filterBinding(\.dueDateFilter),
                        minimumSegmentWidth: 126,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }

                if store.filters.taskListMode != .routines {
                    HomeMacAdaptiveFilterControlRow("Status") {
                        HomeMacAdaptiveFilterChoiceControl(
                            accessibilityLabel: "Backlog one-time status",
                            options: todoStateOptions,
                            selection: filterBinding(\.selectedTodoState),
                            minimumSegmentWidth: 92,
                            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                        ) { state in
                            if let state {
                                Label(state.displayTitle, systemImage: state.systemImage)
                            } else {
                                Label("All", systemImage: "circle.grid.2x2")
                            }
                        }
                    }
                }

                HomeMacAdaptiveFilterControlRow("Media") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog media",
                        options: TaskMediaFilter.allCases,
                        selection: filterBinding(\.selectedMediaFilter),
                        minimumSegmentWidth: 104,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }
            }
        }
    }

    private var sortTabContent: some View {
        HomeMacSidebarSectionCard(title: "Sorting") {
            HomeMacAdaptiveFilterControlRow("Sort") {
                HomeMacAdaptiveFilterChoiceControl(
                    accessibilityLabel: "Backlog sort order",
                    options: BacklogSortOrder.allCases,
                    selection: filterBinding(\.sortOrder),
                    minimumSegmentWidth: 126,
                    compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                ) { order in
                    Label(order.title, systemImage: order.systemImage)
                }
            }
        }
    }

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Backlog Row") {
            HomeMacFilterAppearanceToggleRow(
                "Multiline Titles",
                subtitle: "Wrap long task titles onto additional lines.",
                isOn: taskRowMultilineTitlesBinding
            )

            ForEach(backlogTaskRowFields) { field in
                HomeMacFilterAppearanceToggleRow(
                    field.title,
                    subtitle: field.subtitle,
                    isOn: taskRowFieldVisibilityBinding(field)
                )
            }

            Text("Shown: \(backlogTaskRowSummaryText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var taskLadderFilters: some View {
        HomeMacTaskLadderFiltersSection(
            selectedImportanceUrgencyFilter: filterBinding(\.selectedImportanceUrgencyFilter),
            selectedPressureFilter: filterBinding(\.selectedPressureFilter),
            selectedThinkingNeededFilter: filterBinding(\.selectedThinkingNeededFilter),
            selectedEstimationFilter: filterBinding(\.selectedEstimationFilter)
        )
    }

    private var tagFilters: some View {
        HomeMacTimelineTagFiltersView(
            availableTags: store.presentation.filterCatalog.tags,
            suggestedRelatedTags: [],
            availableExcludeTags: store.presentation.filterCatalog.tags,
            selectedTags: store.filters.selectedTags,
            includeTagMatchMode: store.filters.includeTagMatchMode,
            excludeTagMatchMode: store.filters.excludeTagMatchMode,
            selectedExcludedTags: store.filters.excludedTags,
            tagCount: { tag in
                store.presentation.filterCatalog.tagCounts[RoutineTag.normalized(tag) ?? tag, default: 0]
            },
            tagColor: { tag in
                guard let hex = store.tagColors[RoutineTag.normalized(tag) ?? tag] else { return nil }
                return Color(hex: hex)
            },
            onSelectTags: { updateFilter(\.selectedTags, to: $0) },
            onIncludeTagMatchModeChange: { updateFilter(\.includeTagMatchMode, to: $0) },
            onSelectSuggestedTag: { tag in
                var tags = store.filters.selectedTags
                tags.insert(tag)
                updateFilter(\.selectedTags, to: tags)
            },
            onExcludeTagMatchModeChange: { updateFilter(\.excludeTagMatchMode, to: $0) },
            onToggleExcludedTag: toggleExcludedTag,
            presentation: .compactActions
        )
    }

    private var flagFilters: some View {
        HomeMacSharedFlagFiltersView(
            availableFlags: store.presentation.filterCatalog.flags,
            selectedFlags: store.filters.selectedFlags,
            excludedFlags: store.filters.excludedFlags,
            includeFlagMatchMode: store.filters.includeFlagMatchMode,
            excludeFlagMatchMode: store.filters.excludeFlagMatchMode,
            onSelectIncludedFlags: { updateFilter(\.selectedFlags, to: $0) },
            onIncludeFlagMatchModeChange: { updateFilter(\.includeFlagMatchMode, to: $0) },
            onSelectExcludedFlags: { updateFilter(\.excludedFlags, to: $0) },
            onExcludeFlagMatchModeChange: { updateFilter(\.excludeFlagMatchMode, to: $0) }
        )
    }

    private var taskRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: backlogTaskRowHiddenFieldsRawValue)
    }

    private var backlogTaskRowFields: [HomeTaskRowField] {
        HomeTaskRowField.backlogAppearanceFields(showsPlaces: isPlacesEnabled)
    }

    private var backlogTaskRowSummaryText: String {
        let visibleCount = backlogTaskRowFields.lazy.filter {
            taskRowVisibility.shows($0)
        }.count
        return visibleCount == backlogTaskRowFields.count
            ? "All fields"
            : "\(visibleCount) of \(backlogTaskRowFields.count) fields"
    }

    private var taskRowMultilineTitlesBinding: Binding<Bool> {
        Binding(
            get: { taskRowVisibility.allowsMultilineTitles },
            set: { isEnabled in
                persistTaskRowVisibility(taskRowVisibility.settingMultilineTitles(isEnabled))
            }
        )
    }

    private func taskRowFieldVisibilityBinding(_ field: HomeTaskRowField) -> Binding<Bool> {
        Binding(
            get: { taskRowVisibility.shows(field) },
            set: { isVisible in
                persistTaskRowVisibility(taskRowVisibility.setting(field, visible: isVisible))
            }
        )
    }

    private func persistTaskRowVisibility(_ visibility: HomeTaskRowVisibility) {
        backlogTaskRowHiddenFieldsRawValue = visibility.storageRawValue ?? ""
        AppSettingsPersistenceMirror.schedule()
    }

    private var todoStateOptions: [TodoState?] {
        [nil] + TodoState.filterableCases.map(Optional.some)
    }

    private var backlogCountLabel: String {
        let count = store.presentation.taskCount
        if HomeTaskSearchIndex.query(store.searchText) != nil {
            return count == 1 ? "1 in Backlog" : "\(count) in Backlog"
        }
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    private var resetButtonTitle: String {
        "Reset \(selectedTab.title)"
    }

    private var canResetSelectedSection: Bool {
        switch selectedTab {
        case .filter:
            return store.filters.hasNonDefaultFilters
        case .sort:
            return store.filters.hasNonDefaultSortOrder
        case .appearance:
            return taskRowVisibility != .backlogDefaultValue
        }
    }

    private func resetSelectedSection() {
        switch selectedTab {
        case .filter:
            store.send(.filtersChanged(store.filters.resettingFilters()))
        case .sort:
            store.send(.filtersChanged(store.filters.resettingSortOrder()))
        case .appearance:
            persistTaskRowVisibility(.backlogDefaultValue)
        }
    }

    private func filterBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<BacklogFilterState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.filters[keyPath: keyPath] },
            set: { updateFilter(keyPath, to: $0) }
        )
    }

    private func updateFilter<Value: Equatable>(
        _ keyPath: WritableKeyPath<BacklogFilterState, Value>,
        to value: Value
    ) {
        guard store.filters[keyPath: keyPath] != value else { return }
        var filters = store.filters
        filters[keyPath: keyPath] = value
        store.send(.filtersChanged(filters))
    }

    private func toggleExcludedTag(_ tag: String) {
        var tags = store.filters.excludedTags
        if let existing = tags.first(where: { RoutineTag.contains($0, in: [tag]) }) {
            tags.remove(existing)
        } else {
            tags.insert(tag)
        }
        updateFilter(\.excludedTags, to: tags)
    }
}
