import SwiftUI

struct HomeFiltersQuerySection: View {
    @Binding var advancedQuery: String
    let options: HomeAdvancedQueryOptions

    var body: some View {
        Section("Query") {
            HomeAdvancedQueryBuilder(query: $advancedQuery, options: options)
        }
    }
}

struct HomeFiltersTaskListModeSection: View {
    @Binding var taskListMode: HomeFeature.TaskListMode

    var body: some View {
        Section("Task Type") {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Task type",
                options: HomeFeature.TaskListMode.allCases,
                selection: $taskListMode,
                fillsAvailableWidth: true
            ) { mode in
                Label(mode.rawValue, systemImage: mode.systemImage)
            }

            Text("Choose which tasks the Home list should show.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct HomeFiltersVisibilitySection: View {
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var hideAssumedDoneTasks: Bool
    @Binding var showArchivedTasks: Bool

    var body: some View {
        Section {
            Toggle("Show blocked tasks", isOn: showBlockedTasksBinding)
                .toggleStyle(.switch)

            Toggle("Don't show assumed done tasks", isOn: $hideAssumedDoneTasks)
                .toggleStyle(.switch)

            Toggle("Show archived list", isOn: $showArchivedTasks)
                .toggleStyle(.switch)
        }
    }

    private var showBlockedTasksBinding: Binding<Bool> {
        Binding(
            get: { taskListViewMode == .all },
            set: { taskListViewMode = $0 ? .all : .actionable }
        )
    }
}

struct HomeFiltersGroupingSection: View {
    @Binding var routineListSectioningMode: RoutineListSectioningMode

    var body: some View {
        Section("Group") {
            Picker("Group rows", selection: $routineListSectioningMode) {
                ForEach(RoutineListSectioningMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Text(routineListSectioningMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct HomeFiltersCreatedSection: View {
    @Binding var createdDateFilter: HomeTaskCreatedDateFilter

    var body: some View {
        Section("Created") {
            Picker("Created", selection: $createdDateFilter) {
                ForEach(HomeTaskCreatedDateFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage).tag(filter)
                }
            }
            .pickerStyle(.inline)
        }
    }
}

struct HomeFiltersSortSection: View {
    @Binding var taskListSortOrder: HomeTaskListSortOrder

    var body: some View {
        Section("Sort") {
            Picker("Task order", selection: $taskListSortOrder) {
                ForEach(HomeTaskListSortOrder.allCases) { order in
                    Label(order.title, systemImage: order.systemImage).tag(order)
                }
            }
            .pickerStyle(.inline)
        }
    }
}

struct HomeFiltersStatusSection: View {
    let placeFilterPluralNoun: String
    let availableFilters: [RoutineListFilter]
    @Binding var selectedFilter: RoutineListFilter

    var body: some View {
        Section("Status") {
            Picker("Show \(placeFilterPluralNoun)", selection: $selectedFilter) {
                ForEach(availableFilters) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.inline)
        }
    }
}

struct HomeFiltersTodoStateSection: View {
    let taskListMode: HomeFeature.TaskListMode
    @Binding var selectedTodoStateFilter: TodoState?

    @ViewBuilder
    var body: some View {
        if taskListMode == .todos || taskListMode == .all {
            Section("Todo State") {
                HomeTodoStateFilterChips(selectedTodoStateFilter: $selectedTodoStateFilter)
                    .padding(.vertical, 4)
            }
        }
    }
}

struct HomeFiltersPressureSection: View {
    @Binding var selectedPressureFilter: RoutineTaskPressure?

    var body: some View {
        Section("Pressure") {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Pressure",
                options: [Optional<RoutineTaskPressure>.none] + RoutineTaskPressure.allCases.map(Optional.some),
                selection: $selectedPressureFilter,
                fillsAvailableWidth: true
            ) { pressure in
                Text(pressure?.title ?? "All")
            }
        }
    }
}

struct HomeFiltersGoalSection: View {
    @Binding var selectedGoalFilter: HomeTaskGoalFilter

    var body: some View {
        Section("Goal") {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Goal",
                options: HomeTaskGoalFilter.allCases,
                selection: $selectedGoalFilter,
                fillsAvailableWidth: true
            ) { filter in
                Text(filter.title)
            }
        }
    }
}

struct HomeFiltersMediaSection: View {
    @Binding var selectedMediaFilter: TaskMediaFilter

    var body: some View {
        Section("Media") {
            Picker("Media", selection: $selectedMediaFilter) {
                ForEach(TaskMediaFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage).tag(filter)
                }
            }
            .pickerStyle(.inline)
        }
    }
}

struct HomeFiltersImportanceUrgencySection: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let summary: String

    var body: some View {
        Section("Importance & Urgency") {
            VStack(alignment: .leading, spacing: 12) {
                Button(selectedImportanceUrgencyFilter == nil ? "All levels selected" : "Show all levels") {
                    selectedImportanceUrgencyFilter = nil
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedImportanceUrgencyFilter == nil ? Color.accentColor : Color.primary)

                ImportanceUrgencyMatrixPicker(selectedFilter: $selectedImportanceUrgencyFilter)
                    .frame(maxWidth: 420, alignment: .leading)

                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

struct HomeFiltersPlaceSection: View {
    let configuration: HomeFiltersPlaceConfiguration
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool

    var body: some View {
        Section("Place") {
            if configuration.hasSavedPlaces {
                Picker("Show \(configuration.placeFilterPluralNoun)", selection: $selectedPlaceID) {
                    Text(configuration.placeFilterAllTitle).tag(Optional<UUID>.none)
                    ForEach(configuration.sortedRoutinePlaces) { place in
                        Text(place.displayName).tag(Optional(place.id))
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text("No saved places yet")
                    .foregroundStyle(.secondary)
            }

            if configuration.hasPlaceLinkedRoutines && configuration.isLocationAuthorized {
                Toggle("Hide unavailable \(configuration.placeFilterPluralNoun)", isOn: $hideUnavailableRoutines)
            }

            Text(configuration.placeFilterSectionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if configuration.hasPlaceLinkedRoutines {
                Text(configuration.locationStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HomeFiltersClearSection: View {
    let hasActiveOptionalFilters: Bool
    let onClearOptionalFilters: () -> Void

    @ViewBuilder
    var body: some View {
        if hasActiveOptionalFilters {
            Section {
                Button("Clear Filters", action: onClearOptionalFilters)
                    .foregroundStyle(.red)
            }
        }
    }
}
