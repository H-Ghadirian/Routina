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
    let sortedRoutinePlaces: [RoutinePlace]
    let hasSavedPlaces: Bool
    let hasPlaceLinkedRoutines: Bool
    let isLocationAuthorized: Bool
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool
    let placeFilterPluralNoun: String
    let placeFilterAllTitle: String
    let placeFilterSectionDescription: String
    let locationStatusText: String

    var body: some View {
        Section("Place") {
            if hasSavedPlaces {
                Picker("Show \(placeFilterPluralNoun)", selection: $selectedPlaceID) {
                    Text(placeFilterAllTitle).tag(Optional<UUID>.none)
                    ForEach(sortedRoutinePlaces) { place in
                        Text(place.displayName).tag(Optional(place.id))
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text("No saved places yet")
                    .foregroundStyle(.secondary)
            }

            if hasPlaceLinkedRoutines && isLocationAuthorized {
                Toggle("Hide unavailable \(placeFilterPluralNoun)", isOn: $hideUnavailableRoutines)
            }

            Text(placeFilterSectionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            if hasPlaceLinkedRoutines {
                Text(locationStatusText)
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
