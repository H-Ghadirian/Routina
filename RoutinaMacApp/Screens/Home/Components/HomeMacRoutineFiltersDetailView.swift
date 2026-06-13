import SwiftUI

struct HomeMacRoutineFiltersDetailView<TagContent: View, PlaceContent: View>: View {
    let availableFilters: [RoutineListFilter]
    @Binding var taskListMode: HomeTaskListMode
    @Binding var selectedFilter: RoutineListFilter
    @Binding var advancedQuery: String
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var routineListSectioningMode: RoutineListSectioningMode
    @Binding var taskListSortOrder: HomeTaskListSortOrder
    @Binding var createdDateFilter: HomeTaskCreatedDateFilter
    @Binding var showArchivedTasks: Bool
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var selectedPressureFilter: RoutineTaskPressure?
    @Binding var selectedGoalFilter: HomeTaskGoalFilter
    @Binding var selectedMediaFilter: TaskMediaFilter
    @Binding var selectedTodoStateFilter: TodoState?
    let queryOptions: HomeAdvancedQueryOptions
    let importanceUrgencySummary: String
    let showsGoalFilter: Bool
    let showsTagSection: Bool
    let showsPlaceSection: Bool
    @ViewBuilder let tagSectionContent: () -> TagContent
    @ViewBuilder let placeSectionContent: () -> PlaceContent

    var body: some View {
        Group {
            HomeMacSidebarSectionCard(title: "Query") {
                queryBuilder
            }

            coreFilterCard

            sortFilterCard

            HomeMacSidebarSectionCard {
                HomeMacImportanceUrgencyDisclosureSection(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )
            }

            if showsTagSection {
                HomeMacSidebarSectionCard {
                    HomeMacCollapsibleFilterSection(title: "Tags") {
                        tagSectionContent()
                    }
                }
            }

            if showsPlaceSection {
                HomeMacSidebarSectionCard {
                    HomeMacCollapsibleFilterSection(title: "Places") {
                        placeSectionContent()
                    }
                }
            }
        }
    }

    private var queryBuilder: some View {
        HomeAdvancedQueryBuilder(query: $advancedQuery, usesFlowLayout: true, options: queryOptions)
    }

    private var taskListModePicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(taskListModeOptions, id: \.title) { option in
                Button {
                    taskListMode = option.mode
                } label: {
                    Label(option.title, systemImage: option.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(taskListMode == option.mode ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(taskListMode == option.mode ? Color.accentColor : Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var taskListModeOptions: [(mode: HomeTaskListMode, title: String, systemImage: String)] {
        [
            (.all, "All", "tray.full"),
            (.todos, "Todos", "checklist"),
            (.routines, "Routines", "repeat")
        ]
    }

    private var coreFilterCard: some View {
        HomeMacSidebarSectionCard(title: "Filters") {
            VStack(alignment: .leading, spacing: 18) {
                filterControlSection("Task type") {
                    taskListModePicker
                }

                filterControlSection("View Mode") {
                    viewModePicker
                }

                filterControlSection("Created") {
                    createdDatePicker
                }

                filterControlSection("Show") {
                    archivedToggle
                    filterPicker
                }

                filterControlSection("Pressure") {
                    pressurePicker
                }

                if showsGoalFilter {
                    filterControlSection("Goal") {
                        goalPicker
                    }
                }

                filterControlSection("Media") {
                    mediaPicker
                }

                if taskListMode == .todos || taskListMode == .all {
                    filterControlSection("Todo State") {
                        todoStateFilterSection
                    }
                }
            }
        }
    }

    private var sortFilterCard: some View {
        HomeMacSidebarSectionCard(title: "Sort") {
            VStack(alignment: .leading, spacing: 18) {
                filterControlSection("Grouping") {
                    groupingPicker
                }

                filterControlSection("Sort") {
                    sortPicker
                }
            }
        }
    }

    private func filterControlSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private var viewModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private var groupingPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 126), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(RoutineListSectioningMode.allCases) { mode in
                    Button {
                        routineListSectioningMode = mode
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(routineListSectioningMode == mode ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(routineListSectioningMode == mode ? Color.accentColor : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(routineListSectioningMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private var goalPicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(HomeTaskGoalFilter.allCases) { filter in
                Button {
                    selectedGoalFilter = filter
                } label: {
                    Text(filter.title)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedGoalFilter == filter ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(selectedGoalFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mediaPicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(TaskMediaFilter.allCases) { filter in
                Button {
                    selectedMediaFilter = filter
                } label: {
                    Label(filter.title, systemImage: filter.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedMediaFilter == filter ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(selectedMediaFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var createdDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private var todoStateFilterSection: some View {
        HomeTodoStateFilterChips(
            selectedTodoStateFilter: $selectedTodoStateFilter,
            layoutStyle: .adaptiveGrid(minimumWidth: 80, spacing: 8),
            selectedForegroundColor: .white,
            unselectedForegroundColor: .primary,
            selectedBackgroundOpacity: 1,
            fillsAvailableWidth: true,
            verticalPadding: 8
        )
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
