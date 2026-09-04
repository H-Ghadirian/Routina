import SwiftUI

struct HomeMacRoutineFiltersDetailView<TagContent: View, PlaceContent: View, FlagContent: View>: View {
    @State private var selectedTab: HomeMacRoutineFilterDetailTab = .filter
    @Environment(\.homeMacFilterDetailLayout) private var filterLayout
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
    @Binding var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    @Binding var selectedGoalFilter: HomeTaskGoalFilter
    @Binding var selectedMediaFilter: TaskMediaFilter
    @Binding var selectedEstimationFilter: TaskEstimationFilter
    @Binding var selectedTodoStateFilter: TodoState?
    let taskRowVisibility: HomeTaskRowVisibility
    let queryOptions: HomeAdvancedQueryOptions
    let importanceUrgencySummary: String
    let showsGoalFilter: Bool
    let showsImportanceUrgencySection: Bool
    let showsTagSection: Bool
    let showsPlaceSection: Bool
    let showsFlagSection: Bool
    let showsPlaceTaskRowField: Bool
    let onTaskRowFieldVisibilityChanged: (HomeTaskRowField, Bool) -> Void
    let onTaskRowMultilineTitlesChanged: (Bool) -> Void
    @ViewBuilder let tagSectionContent: () -> TagContent
    @ViewBuilder let placeSectionContent: () -> PlaceContent
    @ViewBuilder let flagSectionContent: () -> FlagContent

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

            if showsFlagSection {
                flagSectionContent()
            }
        }
    }

    private var sortTabContent: some View {
        HomeMacSidebarSectionCard(title: "Sorting") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HomeMacAdaptiveFilterControlRow("Grouping") {
                        groupingPicker
                    }

                    groupingSupplementaryContent
                }

                HomeMacAdaptiveFilterControlRow("Sort") {
                    sortPicker
                }
            }
        }
    }

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Task Row") {
            HomeMacFilterAppearanceToggleRow(
                "Multiline Titles",
                subtitle: "Wrap long task titles onto additional lines.",
                isOn: taskRowMultilineTitlesBinding
            )

            ForEach(macTaskRowFields) { field in
                HomeMacFilterAppearanceToggleRow(
                    field.title,
                    subtitle: field.subtitle,
                    isOn: taskRowFieldVisibilityBinding(field)
                )
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
            minimumSegmentWidth: 112,
            fillsAvailableWidth: filterLayout.fillsAvailableWidth
        ) { mode in
            Label(mode.title, systemImage: taskListModeSystemImage(mode))
        }
    }

    private var taskListModeOptions: [HomeTaskListMode] {
        [.all, .todos, .routines]
    }

    private func taskListModeSystemImage(_ mode: HomeTaskListMode) -> String {
        switch mode {
        case .all:
            return "tray.full"
        case .todos:
            return "checklist"
        case .routines:
            return "repeat"
        }
    }

    private var coreFilterCard: some View {
        HomeMacSidebarSectionCard(title: "Filters") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    blockedTasksToggle
                    assumedDoneTasksToggle
                    archivedToggle
                }

                filterControlSection("Task type") {
                    taskListModePicker
                }

                HomeMacAdaptiveFilterControlRow("Created") {
                    createdDatePicker
                }

                HomeMacAdaptiveFilterControlRow(
                    "Status",
                    pairsInCompactLayout: availableFilters.count > 3
                ) {
                    filterPicker
                }

                if showsGoalFilter {
                    filterControlSection("Goal") {
                        goalPicker
                    }
                }

                HomeMacAdaptiveFilterControlRow("Media") {
                    mediaPicker
                }

                if taskListMode == .todos || taskListMode == .all {
                    HomeMacAdaptiveFilterControlRow("One-time State") {
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
        HomeMacFilterAppearanceToggleRow(
            "Show blocked tasks",
            isOn: showBlockedTasksBinding
        )
    }

    private var showBlockedTasksBinding: Binding<Bool> {
        Binding(
            get: { taskListViewMode == .all },
            set: { taskListViewMode = $0 ? .all : .actionable }
        )
    }

    private var filterPicker: some View {
        HomeMacAdaptiveFilterChoiceControl(
            accessibilityLabel: "Status filter",
            options: availableFilters,
            selection: $selectedFilter,
            minimumSegmentWidth: 92,
            usesPickerInCompactLayout: availableFilters.count > 3,
            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
        ) { filter in
            Text(filter.title)
        }
    }

    private var groupingPicker: some View {
        HomeMacAdaptiveFilterChoiceControl(
            accessibilityLabel: "Grouping",
            options: RoutineListSectioningMode.allCases,
            selection: $routineListSectioningMode,
            minimumSegmentWidth: 126,
            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
        ) { mode in
            Label(mode.title, systemImage: mode.systemImage)
        }
    }

    private var groupingSupplementaryContent: some View {
        Group {
            Text(routineListSectioningMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if routineListSectioningMode == .tags {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show overdue and due soon separately", isOn: $separateDeadlineStatusInTagSections)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity)

                    Toggle("Separate one-time and repeating tasks", isOn: $separateTodosAndRoutinesInTagSections)
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
        }
    }

    private var sortPicker: some View {
        HomeMacAdaptiveFilterChoiceControl(
            accessibilityLabel: "Sort",
            options: HomeTaskListSortOrder.allCases,
            selection: $taskListSortOrder,
            minimumSegmentWidth: 126,
            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
        ) { order in
            Label(order.title, systemImage: order.systemImage)
        }
    }

    private var goalPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Goal",
            options: HomeTaskGoalFilter.allCases,
            selection: $selectedGoalFilter,
            minimumSegmentWidth: 92,
            fillsAvailableWidth: filterLayout.fillsAvailableWidth
        ) { filter in
            Text(filter.title)
        }
    }

    private var mediaPicker: some View {
        HomeMacAdaptiveFilterChoiceControl(
            accessibilityLabel: "Media",
            options: TaskMediaFilter.allCases,
            selection: $selectedMediaFilter,
            minimumSegmentWidth: 104,
            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
        ) { filter in
            Label(filter.title, systemImage: filter.systemImage)
        }
    }

    private var createdDatePicker: some View {
        HomeMacAdaptiveFilterChoiceControl(
            accessibilityLabel: "Created",
            options: HomeTaskCreatedDateFilter.allCases,
            selection: $createdDateFilter,
            minimumSegmentWidth: 126,
            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
        ) { filter in
            Label(filter.title, systemImage: filter.systemImage)
        }
    }

    private var archivedToggle: some View {
        HomeMacFilterAppearanceToggleRow(
            "Show archived list",
            isOn: $showArchivedTasks
        )
    }

    private var assumedDoneTasksToggle: some View {
        HomeMacFilterAppearanceToggleRow(
            "Hide assumed-done tasks",
            isOn: $hideAssumedDoneTasks
        )
    }

    private var todoStateFilterSection: some View {
        HomeMacAdaptiveFilterChoiceControl(
            accessibilityLabel: "One-time State",
            options: todoStateOptions,
            selection: $selectedTodoStateFilter,
            minimumSegmentWidth: 80,
            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
        ) { state in
            Text(state?.displayTitle ?? "Any State")
        }
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

    private var taskRowMultilineTitlesBinding: Binding<Bool> {
        Binding(
            get: { taskRowVisibility.allowsMultilineTitles },
            set: { onTaskRowMultilineTitlesChanged($0) }
        )
    }

    private var macTaskRowFields: [HomeTaskRowField] {
        HomeTaskRowField.availableAppearanceFields(
            showsTaskTypeBadge: false,
            showsGoals: showsGoalFilter,
            showsPlaces: showsPlaceTaskRowField,
            showsFlags: true
        )
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
