import SwiftUI

struct HomeFiltersViewModeSection: View {
    @Binding var taskListViewMode: HomeTaskListViewMode

    var body: some View {
        Section("View Mode") {
            Picker("List view", selection: $taskListViewMode) {
                ForEach(HomeTaskListViewMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(taskListViewMode == .actionable
                ? "Showing tasks without unfinished blockers."
                : "Showing every task that matches your filters.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            Picker("Pressure", selection: $selectedPressureFilter) {
                Text("All").tag(Optional<RoutineTaskPressure>.none)
                ForEach(RoutineTaskPressure.allCases, id: \.self) { pressure in
                    Text(pressure.title).tag(Optional(pressure))
                }
            }
            .pickerStyle(.segmented)
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
