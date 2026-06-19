import SwiftUI

struct HomeMacRoutineFiltersDetailView<TagContent: View, PlaceContent: View>: View {
    @State private var selectedTab: HomeMacRoutineFilterDetailTab = .filter

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
    let taskRowVisibility: HomeTaskRowVisibility
    let queryOptions: HomeAdvancedQueryOptions
    let importanceUrgencySummary: String
    let showsGoalFilter: Bool
    let showsTagSection: Bool
    let showsPlaceSection: Bool
    let onTaskRowFieldVisibilityChanged: (HomeTaskRowField, Bool) -> Void
    @ViewBuilder let tagSectionContent: () -> TagContent
    @ViewBuilder let placeSectionContent: () -> PlaceContent

    var body: some View {
        Group {
            tabPicker

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

    private var tabPicker: some View {
        HomeMacRoutineFilterDetailTabStrip(selection: $selectedTab)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var filterTabContent: some View {
        Group {
            HomeMacSidebarSectionCard(title: "Query") {
                queryBuilder
            }

            coreFilterCard

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

    private var sortTabContent: some View {
        HomeMacSidebarSectionCard(title: "Sorting") {
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

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Task Row") {
            ForEach(macTaskRowFields) { field in
                Toggle(isOn: taskRowFieldVisibilityBinding(field)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.title)
                        Text(field.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Text("Shown: \(macTaskRowSummaryText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        HomeMacSidebarSectionCard {
            HomeMacCollapsibleFilterSection(title: "Filters") {
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

    private func taskRowFieldVisibilityBinding(_ field: HomeTaskRowField) -> Binding<Bool> {
        Binding(
            get: { taskRowVisibility.shows(field) },
            set: { onTaskRowFieldVisibilityChanged(field, $0) }
        )
    }

    private var macTaskRowFields: [HomeTaskRowField] {
        HomeTaskRowField.allCases.filter { field in
            field != .taskTypeBadge
                && (showsGoalFilter || field != .goals)
        }
    }

    private var macTaskRowSummaryText: String {
        let hiddenCount = macTaskRowFields.filter {
            !taskRowVisibility.shows($0)
        }.count
        guard hiddenCount > 0 else { return "All fields" }
        return "\(macTaskRowFields.count - hiddenCount) of \(macTaskRowFields.count) fields"
    }
}

private struct HomeMacRoutineFilterDetailTabStrip: View {
    @Binding var selection: HomeMacRoutineFilterDetailTab
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(HomeMacRoutineFilterDetailTab.allCases) { tab in
                    segmentButton(for: tab)
                }
            }
            .padding(5)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        .frame(width: 520)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Task list tabs")
    }

    private func segmentButton(for tab: HomeMacRoutineFilterDetailTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = tab
            }
        } label: {
            Text(tab.title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .glassEffect(
                        .regular.tint(Color.accentColor.opacity(0.34)).interactive(),
                        in: .rect(cornerRadius: 11)
                    )
                    .glassEffectID("HomeMacRoutineFilterDetailTabSelection", in: glassNamespace)
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private enum HomeMacRoutineFilterDetailTab: String, CaseIterable, Identifiable {
    case filter
    case sort
    case appearance

    var id: Self { self }

    var title: String {
        switch self {
        case .filter: return "Filter"
        case .sort: return "Sort"
        case .appearance: return "Appearance"
        }
    }
}
