import SwiftUI

struct HomeMacRoutineFiltersDetailView<TagContent: View, PlaceContent: View>: View {
    let availableFilters: [RoutineListFilter]
    @Binding var selectedFilter: RoutineListFilter
    @Binding var advancedQuery: String
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var taskListSortOrder: HomeTaskListSortOrder
    @Binding var createdDateFilter: HomeTaskCreatedDateFilter
    @Binding var showArchivedTasks: Bool
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var selectedPressureFilter: RoutineTaskPressure?
    let queryOptions: HomeAdvancedQueryOptions
    let importanceUrgencySummary: String
    let showsTagSection: Bool
    let showsPlaceSection: Bool
    @ViewBuilder let tagSectionContent: () -> TagContent
    @ViewBuilder let placeSectionContent: () -> PlaceContent

    var body: some View {
        Group {
            HomeMacSidebarSectionCard(title: "Query") {
                queryBuilder
            }

            HomeMacSidebarSectionCard {
                viewModePicker
            }

            HomeMacSidebarSectionCard {
                sortPicker
            }

            HomeMacSidebarSectionCard {
                createdDatePicker
            }

            HomeMacSidebarSectionCard {
                archivedToggle
            }

            HomeMacSidebarSectionCard {
                filterPicker
            }

            HomeMacSidebarSectionCard(title: "Pressure") {
                pressurePicker
            }

            HomeMacSidebarSectionCard(title: "Importance & Urgency") {
                HomeMacImportanceUrgencyMatrixView(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )
            }

            if showsTagSection {
                HomeMacSidebarSectionCard {
                    tagSectionContent()
                }
            }

            if showsPlaceSection {
                HomeMacSidebarSectionCard {
                    placeSectionContent()
                }
            }
        }
    }

    private var queryBuilder: some View {
        HomeAdvancedQueryBuilder(query: $advancedQuery, usesFlowLayout: true, options: queryOptions)
    }

    private var viewModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("View Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(HomeTaskListViewMode.allCases) { mode in
                    Button {
                        taskListViewMode = mode
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(taskListViewMode == mode ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(taskListViewMode == mode ? Color.accentColor : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(taskListViewMode == .actionable
                ? "Showing tasks without unfinished blockers."
                : "Showing every task that matches your filters.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var filterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(availableFilters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 126), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(HomeTaskListSortOrder.allCases) { order in
                    Button {
                        taskListSortOrder = order
                    } label: {
                        Label(order.title, systemImage: order.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(taskListSortOrder == order ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(taskListSortOrder == order ? Color.accentColor : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pressurePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                pressureButton(title: "All", pressure: nil)
                ForEach(RoutineTaskPressure.allCases, id: \.self) { pressure in
                    pressureButton(title: pressure.title, pressure: pressure)
                }
            }
        }
    }

    private var createdDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Created")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 126), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(HomeTaskCreatedDateFilter.allCases) { filter in
                    Button {
                        createdDateFilter = filter
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(createdDateFilter == filter ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(createdDateFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var archivedToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show archived list", isOn: $showArchivedTasks)

            Text(showArchivedTasks
                ? "Archived routines and todos are shown in their own list."
                : "Archived routines and todos are hidden from the task list.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func pressureButton(title: String, pressure: RoutineTaskPressure?) -> some View {
        Button {
            selectedPressureFilter = pressure
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(selectedPressureFilter == pressure ? Color.white : Color.primary)
                .background(
                    Capsule()
                        .fill(selectedPressureFilter == pressure ? Color.accentColor : Color.secondary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}
