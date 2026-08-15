import SwiftUI

struct HomeFiltersSheetView<TagPicker: View>: View {
    let configuration: HomeFiltersSheetConfiguration
    let bindings: HomeFilterBindings
    let flagData: HomeFlagFilterData
    let actions: HomeFiltersSheetActions
    let tagPicker: () -> TagPicker
    let tagSuggestions: () -> [String]

    @AppStorage(
        UserDefaultBoolValueKey.appSettingFilterQuerySectionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var showsFilterQuerySections = false
    @State private var presentedDetail: IOSFilterDetailDestination?

    var body: some View {
        NavigationStack {
            List {
                if showsFilterQuerySections {
                    HomeFiltersQuerySection(
                        advancedQuery: bindings.advancedQuery,
                        onPresent: presentDetail
                    )
                }
                HomeFiltersTaskListModeSection(
                    taskListMode: bindings.taskListMode,
                    onPresent: presentDetail
                )
                HomeFiltersVisibilitySection(
                    taskListViewMode: bindings.taskListViewMode,
                    hideAssumedDoneTasks: bindings.hideAssumedDoneTasks,
                    showArchivedTasks: bindings.showArchivedTasks,
                    onPresent: presentDetail
                )
                HomeFiltersGroupingSection(
                    routineListSectioningMode: bindings.routineListSectioningMode,
                    onPresent: presentDetail
                )
                HomeFiltersSortSection(
                    taskListSortOrder: bindings.taskListSortOrder,
                    onPresent: presentDetail
                )
                HomeFiltersCreatedSection(
                    createdDateFilter: bindings.createdDateFilter,
                    onPresent: presentDetail
                )
                HomeFiltersStatusSection(
                    placeFilterPluralNoun: configuration.place.placeFilterPluralNoun,
                    availableFilters: configuration.availableFilters,
                    selectedFilter: bindings.selectedFilter,
                    onPresent: presentDetail
                )
                HomeFiltersTodoStateSection(
                    taskListMode: configuration.taskListMode,
                    selectedTodoStateFilter: bindings.selectedTodoStateFilter,
                    onPresent: presentDetail
                )
                HomeFiltersPressureSection(
                    selectedPressureFilter: bindings.selectedPressureFilter,
                    onPresent: presentDetail
                )
                HomeFiltersThinkingNeededSection(
                    selectedThinkingNeededFilter: bindings.selectedThinkingNeededFilter,
                    onPresent: presentDetail
                )
                if configuration.isGoalsEnabled {
                    HomeFiltersGoalSection(
                        selectedGoalFilter: bindings.selectedGoalFilter,
                        onPresent: presentDetail
                    )
                }
                HomeFiltersMediaSection(
                    selectedMediaFilter: bindings.selectedMediaFilter,
                    onPresent: presentDetail
                )
                HomeFiltersEstimationSection(
                    selectedEstimationFilter: bindings.selectedEstimationFilter,
                    onPresent: presentDetail
                )
                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter,
                    summary: configuration.importanceUrgencySummary,
                    onPresent: presentDetail
                )
                HomeFiltersTagFilterEntrySection(
                    selectedTags: bindings.selectedTags,
                    excludedTags: bindings.excludedTags,
                    onPresent: presentDetail
                )
                HomeFiltersFlagSection(
                    includeFlagMatchMode: bindings.includeFlagMatchMode,
                    data: flagData,
                    actions: actions.flagActions,
                    onPresent: presentDetail
                )
                if configuration.place.isPlacesEnabled {
                    HomeFiltersPlaceSection(
                        configuration: configuration.place,
                        selectedPlaceID: bindings.selectedPlaceID,
                        hideUnavailableRoutines: bindings.hideUnavailableRoutines,
                        onPresent: presentDetail
                    )
                }
                HomeFiltersClearSection(
                    hasActiveOptionalFilters: configuration.hasActiveOptionalFilters,
                    onClearOptionalFilters: actions.onClearOptionalFilters
                )
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: actions.onDismiss)
                }
            }
        }
        .sheet(item: $presentedDetail, content: detailSheet)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func presentDetail(_ destination: IOSFilterDetailDestination) {
        presentedDetail = destination
    }

    @ViewBuilder
    private func detailSheet(
        _ destination: IOSFilterDetailDestination
    ) -> some View {
        switch destination {
        case .advancedQuery:
            HomeFiltersDetailSheet(title: "Advanced Query") {
                Section {
                    HomeAdvancedQueryBuilder(
                        query: bindings.advancedQuery,
                        options: HomeAdvancedQueryOptions(
                            tags: tagSuggestions(),
                            places: configuration.place.isPlacesEnabled
                                ? configuration.place.sortedRoutinePlaces.map(\.displayName)
                                : []
                        )
                    )
                }
            }
        case .homeTaskType:
            HomeFiltersDetailSheet(title: "Task Type") {
                Section {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Task type",
                        options: HomeFeature.TaskListMode.allCases,
                        selection: bindings.taskListMode,
                        minimumSegmentWidth: 82,
                        horizontalPadding: 10,
                        fillsAvailableWidth: true
                    ) { mode in
                        Text(mode.title)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } footer: {
                    Text("Choose which tasks the Home list should show.")
                }
            }
        case .visibility:
            HomeFiltersDetailSheet(title: "Visibility") {
                Section {
                    Toggle("Show blocked tasks", isOn: showBlockedTasksBinding)
                        .toggleStyle(.switch)

                    Toggle("Hide assumed-done tasks", isOn: bindings.hideAssumedDoneTasks)
                        .toggleStyle(.switch)

                    Toggle("Show archived list", isOn: bindings.showArchivedTasks)
                        .toggleStyle(.switch)
                }
            }
        case .grouping:
            HomeFiltersGroupingPickerSheet(
                routineListSectioningMode: bindings.routineListSectioningMode
            )
        case .sort:
            HomeFiltersSortPickerSheet(taskListSortOrder: bindings.taskListSortOrder)
        case .created:
            HomeFiltersDetailSheet(title: "Created") {
                Section {
                    Picker("Created", selection: bindings.createdDateFilter) {
                        ForEach(HomeTaskCreatedDateFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .status:
            HomeFiltersDetailSheet(title: "Status") {
                Section {
                    Picker(
                        "Show \(configuration.place.placeFilterPluralNoun)",
                        selection: bindings.selectedFilter
                    ) {
                        ForEach(configuration.availableFilters) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .todoState:
            HomeFiltersDetailSheet(title: "Todo State") {
                Section {
                    HomeTodoStateFilterChips(
                        selectedTodoStateFilter: bindings.selectedTodoStateFilter
                    )
                    .padding(.vertical, 4)
                }
            }
        case .pressure:
            HomeFiltersDetailSheet(title: "Pressure") {
                Section {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Pressure",
                        options: [Optional<RoutineTaskPressure>.none]
                            + RoutineTaskPressure.allCases.map(Optional.some),
                        selection: bindings.selectedPressureFilter,
                        horizontalPadding: 10,
                        verticalPadding: 8,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 3
                    ) { pressure in
                        Text(pressure?.title ?? "All")
                    }
                }
            }
        case .thinkingNeeded:
            HomeFiltersDetailSheet(title: "Thinking Needed") {
                Section {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Thinking needed",
                        options: [Optional<RoutineTaskThinkingNeeded>.none]
                            + RoutineTaskThinkingNeeded.allCases.map(Optional.some),
                        selection: bindings.selectedThinkingNeededFilter,
                        horizontalPadding: 10,
                        verticalPadding: 8,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 3
                    ) { level in
                        Text(level?.title ?? "All")
                    }
                }
            }
        case .goal:
            HomeFiltersDetailSheet(title: "Goal") {
                Section {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Goal",
                        options: HomeTaskGoalFilter.allCases,
                        selection: bindings.selectedGoalFilter,
                        fillsAvailableWidth: true
                    ) { filter in
                        Text(filter.title)
                    }
                }
            }
        case .media:
            HomeFiltersDetailSheet(title: "Media") {
                Section {
                    Picker("Media", selection: bindings.selectedMediaFilter) {
                        ForEach(TaskMediaFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .estimation:
            HomeFiltersDetailSheet(title: "Estimation") {
                Section {
                    Picker("Duration estimate", selection: bindings.selectedEstimationFilter) {
                        ForEach(TaskEstimationFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .priority:
            HomeFiltersPriorityPickerSheet(
                selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter,
                summary: configuration.importanceUrgencySummary
            )
        case .tags:
            tagPicker()
        case .flags:
            HomeFiltersFlagPickerSheet(
                includeFlagMatchMode: bindings.includeFlagMatchMode,
                data: flagData,
                actions: actions.flagActions
            )
        case .place:
            HomeFiltersDetailSheet(title: "Place") {
                Section {
                    if configuration.place.hasSavedPlaces {
                        Picker(
                            "Show \(configuration.place.placeFilterPluralNoun)",
                            selection: bindings.selectedPlaceID
                        ) {
                            Text(configuration.place.placeFilterAllTitle).tag(Optional<UUID>.none)
                            ForEach(configuration.place.sortedRoutinePlaces) { place in
                                Text(place.displayName).tag(Optional(place.id))
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text("No saved places yet")
                            .foregroundStyle(.secondary)
                    }

                    if configuration.place.hasPlaceLinkedRoutines
                        && configuration.place.isLocationAuthorized {
                        Toggle(
                            "Hide unavailable \(configuration.place.placeFilterPluralNoun)",
                            isOn: bindings.hideUnavailableRoutines
                        )
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configuration.place.placeFilterSectionDescription)

                        if configuration.place.hasPlaceLinkedRoutines {
                            Text(configuration.place.locationStatusText)
                        }
                    }
                }
            }
        case .statsTaskType, .timelineRange, .timelineType:
            EmptyView()
        }
    }

    private var showBlockedTasksBinding: Binding<Bool> {
        Binding(
            get: { bindings.taskListViewMode.wrappedValue == .all },
            set: { bindings.taskListViewMode.wrappedValue = $0 ? .all : .actionable }
        )
    }
}
