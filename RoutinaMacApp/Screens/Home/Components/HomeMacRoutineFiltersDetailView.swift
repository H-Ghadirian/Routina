import SwiftUI

struct HomeMacRoutineFiltersDetailView<TagContent: View, PlaceContent: View>: View {
    @State private var selectedTab: HomeMacRoutineFilterDetailTab = .filter
    @AppStorage(
        UserDefaultBoolValueKey.appSettingFilterQuerySectionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var showsFilterQuerySections = false

    let availableFilters: [RoutineListFilter]
    @Binding var taskListMode: HomeTaskListMode
    @Binding var selectedFilter: RoutineListFilter
    @Binding var advancedQuery: String
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var routineListSectioningMode: RoutineListSectioningMode
    @Binding var separateTodosAndRoutinesInTagSections: Bool
    @Binding var separateDeadlineStatusInTagSections: Bool
    @Binding var taskListSortOrder: HomeTaskListSortOrder
    @Binding var createdDateFilter: HomeTaskCreatedDateFilter
    @Binding var hideAssumedDoneTasks: Bool
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
    let showsImportanceUrgencySection: Bool
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
            if showsFilterQuerySections {
                HomeMacSidebarSectionCard(title: "Query") {
                    queryBuilder
                }
            }

            coreFilterCard

            if showsImportanceUrgencySection {
                HomeMacImportanceUrgencyDisclosureSection(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )
            }

            if showsTagSection {
                HomeMacCollapsibleFilterSection(
                    title: "Tags",
                    systemImage: "tag.fill",
                    tint: .teal
                ) {
                    tagSectionContent()
                }
            }

            if showsPlaceSection {
                HomeMacCollapsibleFilterSection(
                    title: "Places",
                    systemImage: "mappin.and.ellipse",
                    tint: .green
                ) {
                    placeSectionContent()
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
                        if let subtitle = field.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Task type",
            options: taskListModeOptions,
            selection: $taskListMode,
            minimumSegmentWidth: 112
        ) { mode in
            Label(mode.title, systemImage: taskListModeSystemImage(mode))
        }
    }

    private var taskListModeOptions: [HomeTaskListMode] {
        [.all, .todos, .routines, .records]
    }

    private func taskListModeSystemImage(_ mode: HomeTaskListMode) -> String {
        switch mode {
        case .all:
            return "tray.full"
        case .todos:
            return "checklist"
        case .routines:
            return "repeat"
        case .records:
            return "chart.bar.doc.horizontal"
        }
    }

    private var coreFilterCard: some View {
        HomeMacCollapsibleFilterSection(
            title: "Filters",
            systemImage: "slider.horizontal.3",
            tint: .accentColor
        ) {
            VStack(alignment: .leading, spacing: 18) {
                filterControlSection("Task type") {
                    taskListModePicker
                }

                VStack(alignment: .leading, spacing: 10) {
                    blockedTasksToggle
                    if taskListMode != .todos {
                        assumedDoneToggle
                    }
                    archivedToggle
                }

                filterControlSection("Created") {
                    createdDatePicker
                }

                filterPicker

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

    private var blockedTasksToggle: some View {
        Toggle("Show blocked tasks", isOn: showBlockedTasksBinding)
            .toggleStyle(.switch)
    }

    private var showBlockedTasksBinding: Binding<Bool> {
        Binding(
            get: { taskListViewMode == .all },
            set: { taskListViewMode = $0 ? .all : .actionable }
        )
    }

    private var filterPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Status filter",
            options: availableFilters,
            selection: $selectedFilter,
            minimumSegmentWidth: 92,
            fillsAvailableWidth: true,
            maximumSegmentsPerRow: availableFilters.count > 3 ? 2 : nil
        ) { filter in
            Text(filter.rawValue)
        }
    }

    private var groupingPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Grouping",
                options: RoutineListSectioningMode.allCases,
                selection: $routineListSectioningMode,
                minimumSegmentWidth: 126,
                fillsAvailableWidth: true,
                maximumSegmentsPerRow: 2
            ) { mode in
                Label(mode.title, systemImage: mode.systemImage)
            }

            Text(routineListSectioningMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if routineListSectioningMode == .tags {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show overdue and due soon separately", isOn: $separateDeadlineStatusInTagSections)
                        .toggleStyle(.switch)

                    Toggle("Separate todos and routines", isOn: $separateTodosAndRoutinesInTagSections)
                        .toggleStyle(.switch)
                }
                .padding(.top, 4)
            }
        }
    }

    private var sortPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Sort",
            options: HomeTaskListSortOrder.allCases,
            selection: $taskListSortOrder,
            minimumSegmentWidth: 126,
            fillsAvailableWidth: true,
            maximumSegmentsPerRow: 2
        ) { order in
            Label(order.title, systemImage: order.systemImage)
        }
    }

    private var pressurePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Pressure",
            options: pressureOptions,
            selection: $selectedPressureFilter,
            minimumSegmentWidth: 92,
            fillsAvailableWidth: true,
            maximumSegmentsPerRow: 2
        ) { pressure in
            Text(pressure?.title ?? "All")
        }
    }

    private var goalPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Goal",
            options: HomeTaskGoalFilter.allCases,
            selection: $selectedGoalFilter,
            minimumSegmentWidth: 92
        ) { filter in
            Text(filter.title)
        }
    }

    private var mediaPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Media",
            options: TaskMediaFilter.allCases,
            selection: $selectedMediaFilter,
            minimumSegmentWidth: 104,
            fillsAvailableWidth: true,
            maximumSegmentsPerRow: 2
        ) { filter in
            Label(filter.title, systemImage: filter.systemImage)
        }
    }

    private var createdDatePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Created",
            options: HomeTaskCreatedDateFilter.allCases,
            selection: $createdDateFilter,
            minimumSegmentWidth: 126,
            fillsAvailableWidth: true,
            maximumSegmentsPerRow: 2
        ) { filter in
            Label(filter.title, systemImage: filter.systemImage)
        }
    }

    private var archivedToggle: some View {
        Toggle("Show archived list", isOn: $showArchivedTasks)
            .toggleStyle(.switch)
    }

    private var assumedDoneToggle: some View {
        Toggle("Show assumed done", isOn: showAssumedDoneTasksBinding)
            .toggleStyle(.switch)
    }

    private var showAssumedDoneTasksBinding: Binding<Bool> {
        Binding(
            get: { !hideAssumedDoneTasks },
            set: { hideAssumedDoneTasks = !$0 }
        )
    }

    private var todoStateFilterSection: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Todo State",
            options: todoStateOptions,
            selection: $selectedTodoStateFilter,
            minimumSegmentWidth: 80,
            fillsAvailableWidth: true,
            maximumSegmentsPerRow: 2
        ) { state in
            Text(state?.displayTitle ?? "Any State")
        }
    }

    private var pressureOptions: [RoutineTaskPressure?] {
        [nil] + RoutineTaskPressure.allCases.map(Optional.some)
    }

    private var todoStateOptions: [TodoState?] {
        [nil] + TodoState.filterableCases.map(Optional.some)
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
            .frame(maxWidth: .infinity)
            .padding(5)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity)
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
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
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
