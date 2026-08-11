import SwiftUI

struct HomeFiltersQuerySection: View {
    @Binding var advancedQuery: String
    let options: () -> HomeAdvancedQueryOptions

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Query",
            title: "Advanced query",
            systemImage: "magnifyingglass",
            value: advancedQuery.isEmpty ? "None" : "Active",
            pickerTitle: "Advanced Query"
        ) {
            Section {
                HomeAdvancedQueryBuilder(query: $advancedQuery, options: options())
            }
        }
    }
}

struct HomeFiltersTaskListModeSection: View {
    @Binding var taskListMode: HomeFeature.TaskListMode

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Task Type",
            title: "Task type",
            systemImage: "checklist",
            value: taskListMode.title,
            pickerTitle: "Task Type"
        ) {
            Section {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Task type",
                    options: HomeFeature.TaskListMode.allCases,
                    selection: $taskListMode,
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
    }
}

struct HomeFiltersVisibilitySection: View {
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var hideAssumedDoneTasks: Bool
    @Binding var showArchivedTasks: Bool

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Visibility",
            title: "Show tasks",
            systemImage: "eye",
            value: visibilitySummary,
            pickerTitle: "Visibility"
        ) {
            Section {
                Toggle("Show blocked tasks", isOn: showBlockedTasksBinding)
                    .toggleStyle(.switch)

                Toggle("Hide assumed-done tasks", isOn: $hideAssumedDoneTasks)
                    .toggleStyle(.switch)

                Toggle("Show archived list", isOn: $showArchivedTasks)
                    .toggleStyle(.switch)
            }
        }
    }

    private var showBlockedTasksBinding: Binding<Bool> {
        Binding(
            get: { taskListViewMode == .all },
            set: { taskListViewMode = $0 ? .all : .actionable }
        )
    }

    private var visibilitySummary: String {
        var selections = [taskListViewMode == .all ? "All tasks" : "Actionable"]
        if hideAssumedDoneTasks {
            selections.append("Assumed-done hidden")
        }
        if showArchivedTasks {
            selections.append("Archived")
        }
        return selections.joined(separator: " • ")
    }
}

struct HomeFiltersGroupingSection: View {
    @Binding var routineListSectioningMode: RoutineListSectioningMode
    @State private var isGroupingPickerPresented = false

    var body: some View {
        Section("Group") {
            HomeFiltersDetailEntry(
                title: "Group rows",
                systemImage: "rectangle.3.group",
                value: routineListSectioningMode.title
            ) {
                isGroupingPickerPresented = true
            }
        }
        .sheet(isPresented: $isGroupingPickerPresented) {
            HomeFiltersGroupingPickerSheet(
                routineListSectioningMode: $routineListSectioningMode
            )
        }
    }
}

struct HomeFiltersCreatedSection: View {
    @Binding var createdDateFilter: HomeTaskCreatedDateFilter

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Created",
            title: "Created",
            systemImage: "calendar",
            value: createdDateFilter.title,
            pickerTitle: "Created"
        ) {
            Section {
                Picker("Created", selection: $createdDateFilter) {
                    ForEach(HomeTaskCreatedDateFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}

struct HomeFiltersSortSection: View {
    @Binding var taskListSortOrder: HomeTaskListSortOrder
    @State private var isSortPickerPresented = false

    var body: some View {
        Section("Sort") {
            HomeFiltersDetailEntry(
                title: "Task order",
                systemImage: "arrow.up.arrow.down",
                value: taskListSortOrder.title
            ) {
                isSortPickerPresented = true
            }
        }
        .sheet(isPresented: $isSortPickerPresented) {
            HomeFiltersSortPickerSheet(taskListSortOrder: $taskListSortOrder)
        }
    }
}

struct HomeFiltersDetailEntry: View {
    let title: String
    let systemImage: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint("Open picker")
    }
}

struct HomeFiltersPickerEntry<Content: View>: View {
    let sectionTitle: String
    let title: String
    let systemImage: String
    let value: String
    let pickerTitle: String
    private let content: () -> Content

    @State private var isPresented = false

    init(
        sectionTitle: String,
        title: String,
        systemImage: String,
        value: String,
        pickerTitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sectionTitle = sectionTitle
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.pickerTitle = pickerTitle
        self.content = content
    }

    var body: some View {
        Section(sectionTitle) {
            HomeFiltersDetailEntry(
                title: title,
                systemImage: systemImage,
                value: value
            ) {
                isPresented = true
            }
        }
        .sheet(isPresented: $isPresented) {
            HomeFiltersDetailSheet(title: pickerTitle, content: content)
        }
    }
}

private struct HomeFiltersDetailSheet<Content: View>: View {
    let title: String
    let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                content()
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct HomeFiltersGroupingPickerSheet: View {
    @Binding var routineListSectioningMode: RoutineListSectioningMode

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Group rows", selection: $routineListSectioningMode) {
                        ForEach(RoutineListSectioningMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } footer: {
                    Text(routineListSectioningMode.subtitle)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Group rows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct HomeFiltersSortPickerSheet: View {
    @Binding var taskListSortOrder: HomeTaskListSortOrder

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Task order", selection: $taskListSortOrder) {
                        ForEach(HomeTaskListSortOrder.allCases) { order in
                            Label(order.title, systemImage: order.systemImage).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Task order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct HomeFiltersStatusSection: View {
    let placeFilterPluralNoun: String
    let availableFilters: [RoutineListFilter]
    @Binding var selectedFilter: RoutineListFilter

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Status",
            title: "Show \(placeFilterPluralNoun)",
            systemImage: "line.3.horizontal.decrease.circle",
            value: selectedFilter.rawValue,
            pickerTitle: "Status"
        ) {
            Section {
                Picker("Show \(placeFilterPluralNoun)", selection: $selectedFilter) {
                    ForEach(availableFilters) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}

struct HomeFiltersTodoStateSection: View {
    let taskListMode: HomeFeature.TaskListMode
    @Binding var selectedTodoStateFilter: TodoState?

    @ViewBuilder
    var body: some View {
        if taskListMode == .todos || taskListMode == .all {
            HomeFiltersPickerEntry(
                sectionTitle: "Todo State",
                title: "Todo state",
                systemImage: "checkmark.circle",
                value: selectedTodoStateFilter?.displayTitle ?? "All",
                pickerTitle: "Todo State"
            ) {
                Section {
                    HomeTodoStateFilterChips(selectedTodoStateFilter: $selectedTodoStateFilter)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

struct HomeFiltersPressureSection: View {
    @Binding var selectedPressureFilter: RoutineTaskPressure?

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Pressure",
            title: "Pressure",
            systemImage: "gauge.with.dots.needle.33percent",
            value: selectedPressureFilter?.title ?? "All",
            pickerTitle: "Pressure"
        ) {
            Section {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Pressure",
                    options: [Optional<RoutineTaskPressure>.none] + RoutineTaskPressure.allCases.map(Optional.some),
                    selection: $selectedPressureFilter,
                    horizontalPadding: 10,
                    verticalPadding: 8,
                    fillsAvailableWidth: true,
                    maximumSegmentsPerRow: 3
                ) { pressure in
                    Text(pressure?.title ?? "All")
                }
            }
        }
    }
}

struct HomeFiltersThinkingNeededSection: View {
    @Binding var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Thinking needed",
            title: "Thinking needed",
            systemImage: "brain.head.profile",
            value: selectedThinkingNeededFilter?.title ?? "All",
            pickerTitle: "Thinking Needed"
        ) {
            Section {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Thinking needed",
                    options: [Optional<RoutineTaskThinkingNeeded>.none]
                        + RoutineTaskThinkingNeeded.allCases.map(Optional.some),
                    selection: $selectedThinkingNeededFilter,
                    horizontalPadding: 10,
                    verticalPadding: 8,
                    fillsAvailableWidth: true,
                    maximumSegmentsPerRow: 3
                ) { level in
                    Text(level?.title ?? "All")
                }
            }
        }
    }
}

struct HomeFiltersGoalSection: View {
    @Binding var selectedGoalFilter: HomeTaskGoalFilter

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Goal",
            title: "Goal",
            systemImage: "target",
            value: selectedGoalFilter.title,
            pickerTitle: "Goal"
        ) {
            Section {
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
}

struct HomeFiltersMediaSection: View {
    @Binding var selectedMediaFilter: TaskMediaFilter

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Media",
            title: "Media",
            systemImage: "paperclip",
            value: selectedMediaFilter.title,
            pickerTitle: "Media"
        ) {
            Section {
                Picker("Media", selection: $selectedMediaFilter) {
                    ForEach(TaskMediaFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}

struct HomeFiltersEstimationSection: View {
    @Binding var selectedEstimationFilter: TaskEstimationFilter

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Estimation",
            title: "Duration estimate",
            systemImage: "timer",
            value: selectedEstimationFilter.title,
            pickerTitle: "Estimation"
        ) {
            Section {
                Picker("Duration estimate", selection: $selectedEstimationFilter) {
                    ForEach(TaskEstimationFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage).tag(filter)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}

struct HomeFiltersImportanceUrgencySection: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let summary: String
    @State private var isPriorityPickerPresented = false

    var body: some View {
        Section("Priority") {
            Button {
                isPriorityPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Label("Filter priority", systemImage: "line.3.horizontal.decrease.circle")
                    Spacer()
                    Text(selectionSummary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter priority")
            .accessibilityValue(selectionAccessibilityValue)
            .accessibilityHint("Open the importance and urgency filter")
        }
        .sheet(isPresented: $isPriorityPickerPresented) {
            HomeFiltersPriorityPickerSheet(
                selectedImportanceUrgencyFilter: $selectedImportanceUrgencyFilter,
                summary: summary
            )
        }
    }

    private var selectionSummary: String {
        guard let selectedImportanceUrgencyFilter else { return "All levels" }
        return "\(selectedImportanceUrgencyFilter.importance.shortTitle)/\(selectedImportanceUrgencyFilter.urgency.shortTitle)+"
    }

    private var selectionAccessibilityValue: String {
        guard let selectedImportanceUrgencyFilter else { return "All priority levels" }
        return "At least \(selectedImportanceUrgencyFilter.importance.title.lowercased()) importance and \(selectedImportanceUrgencyFilter.urgency.title.lowercased()) urgency"
    }
}

private struct HomeFiltersPriorityPickerSheet: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let summary: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Show all priority levels") {
                        selectedImportanceUrgencyFilter = nil
                    }
                    .disabled(selectedImportanceUrgencyFilter == nil)

                    ImportanceUrgencyMatrixPicker(
                        selectedFilter: $selectedImportanceUrgencyFilter,
                        showsSummaryChip: false
                    )
                    .frame(maxWidth: 420, alignment: .leading)
                } header: {
                    Text("Priority")
                } footer: {
                    Text(summary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct HomeFiltersPlaceSection: View {
    let configuration: HomeFiltersPlaceConfiguration
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool

    var body: some View {
        HomeFiltersPickerEntry(
            sectionTitle: "Place",
            title: "Place",
            systemImage: "mappin.and.ellipse",
            value: placeSummary,
            pickerTitle: "Place"
        ) {
            Section {
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
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configuration.placeFilterSectionDescription)

                    if configuration.hasPlaceLinkedRoutines {
                        Text(configuration.locationStatusText)
                    }
                }
            }
        }
    }

    private var placeSummary: String {
        var selections = [
            configuration.sortedRoutinePlaces.first(where: { $0.id == selectedPlaceID })?.displayName
                ?? configuration.placeFilterAllTitle
        ]
        if hideUnavailableRoutines {
            selections.append("Hide unavailable")
        }
        return selections.joined(separator: " • ")
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
