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
                Section("Priority") {
                    HomeFiltersImportanceUrgencyEntries(
                        selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter,
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
                }
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
                    Picker("Task type", selection: bindings.taskListMode) {
                        ForEach(HomeFeature.TaskListMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
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
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .todoState:
            HomeFiltersDetailSheet(title: "One-time State") {
                Section {
                    Picker("One-time state", selection: bindings.selectedTodoStateFilter) {
                        Label("Any state", systemImage: "square.grid.2x2")
                            .tag(Optional<TodoState>.none)

                        ForEach(TodoState.filterableCases) { state in
                            Label(state.displayTitle, systemImage: state.systemImage)
                                .tag(Optional(state))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .pressure:
            HomeFiltersDetailSheet(title: "Pressure") {
                Section {
                    Picker("Pressure", selection: bindings.selectedPressureFilter) {
                        ForEach(pressureOptions, id: \.self) { pressure in
                            Text(pressure?.title ?? "All").tag(pressure)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("All does not filter by pressure. None shows tasks without a recorded pressure value.")
                }
            }
        case .thinkingNeeded:
            HomeFiltersDetailSheet(title: "Thinking Needed") {
                Section {
                    Picker("Thinking needed", selection: bindings.selectedThinkingNeededFilter) {
                        ForEach(thinkingNeededOptions, id: \.self) { level in
                            Text(level?.title ?? "All").tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("All does not filter by thinking needed. None shows tasks without a recorded thinking-needed value.")
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
        case .importance:
            HomeFiltersImportancePickerSheet(
                selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter
            )
        case .urgency:
            HomeFiltersUrgencyPickerSheet(
                selectedImportanceUrgencyFilter: bindings.selectedImportanceUrgencyFilter
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
            placeFilterSheet
        case .statsTaskType, .timelineRange, .timelineType:
            EmptyView()
        }
    }

    private var placeFilterSheet: some View {
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
    }

    private var showBlockedTasksBinding: Binding<Bool> {
        Binding(
            get: { bindings.taskListViewMode.wrappedValue == .all },
            set: { bindings.taskListViewMode.wrappedValue = $0 ? .all : .actionable }
        )
    }

    private var pressureOptions: [RoutineTaskPressure?] {
        [nil] + RoutineTaskPressure.allCases.map(Optional.some)
    }

    private var thinkingNeededOptions: [RoutineTaskThinkingNeeded?] {
        [nil] + RoutineTaskThinkingNeeded.allCases.map(Optional.some)
    }
}
