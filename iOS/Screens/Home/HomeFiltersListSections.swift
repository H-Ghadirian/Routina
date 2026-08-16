import SwiftUI

enum IOSFilterDetailDestination: String, Identifiable {
    case advancedQuery
    case homeTaskType
    case visibility
    case grouping
    case sort
    case created
    case status
    case todoState
    case pressure
    case thinkingNeeded
    case goal
    case media
    case estimation
    case priority
    case tags
    case flags
    case place
    case statsTaskType
    case timelineRange
    case timelineType

    var id: String { rawValue }
}

struct HomeFiltersQuerySection: View {
    @Binding var advancedQuery: String
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Advanced query",
            systemImage: "magnifyingglass",
            value: advancedQuery.isEmpty ? "None" : "Active",
            destination: .advancedQuery,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersTaskListModeSection: View {
    @Binding var taskListMode: HomeFeature.TaskListMode
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Task type",
            systemImage: "checklist",
            value: taskListMode.title,
            destination: .homeTaskType,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersVisibilitySection: View {
    @Binding var taskListViewMode: HomeTaskListViewMode
    @Binding var hideAssumedDoneTasks: Bool
    @Binding var showArchivedTasks: Bool
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Show tasks",
            systemImage: "eye",
            value: visibilitySummary,
            destination: .visibility,
            onPresent: onPresent
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
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersDetailEntry(
            title: "Group rows",
            systemImage: "rectangle.3.group",
            value: routineListSectioningMode.title
        ) {
            onPresent(.grouping)
        }
    }
}

struct HomeFiltersCreatedSection: View {
    @Binding var createdDateFilter: HomeTaskCreatedDateFilter
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Created",
            systemImage: "calendar",
            value: createdDateFilter.title,
            destination: .created,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersSortSection: View {
    @Binding var taskListSortOrder: HomeTaskListSortOrder
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersDetailEntry(
            title: "Task order",
            systemImage: "arrow.up.arrow.down",
            value: taskListSortOrder.title
        ) {
            onPresent(.sort)
        }
    }
}

struct HomeFiltersDetailEntry: View {
    let title: String
    let systemImage: String
    let value: String
    var allowsMultilineValue = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .lineLimit(allowsMultilineValue ? 1 : nil)
                    .layoutPriority(allowsMultilineValue ? 1 : 0)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(allowsMultilineValue ? nil : 1)
                    .fixedSize(horizontal: false, vertical: allowsMultilineValue)
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

struct HomeFiltersPickerEntry: View {
    let title: String
    let systemImage: String
    let value: String
    let destination: IOSFilterDetailDestination
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersDetailEntry(
            title: title,
            systemImage: systemImage,
            value: value
        ) {
            onPresent(destination)
        }
    }
}

struct HomeFiltersDetailSheet<Content: View>: View {
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

struct HomeFiltersGroupingPickerSheet: View {
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
                    .labelsHidden()
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

struct HomeFiltersSortPickerSheet: View {
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
                    .labelsHidden()
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
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Show \(placeFilterPluralNoun)",
            systemImage: "line.3.horizontal.decrease.circle",
            value: selectedFilter.rawValue,
            destination: .status,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersTodoStateSection: View {
    let taskListMode: HomeFeature.TaskListMode
    @Binding var selectedTodoStateFilter: TodoState?
    let onPresent: (IOSFilterDetailDestination) -> Void

    @ViewBuilder
    var body: some View {
        if taskListMode == .todos || taskListMode == .all {
            HomeFiltersPickerEntry(
                title: "Todo state",
                systemImage: "checkmark.circle",
                value: selectedTodoStateFilter?.displayTitle ?? "All",
                destination: .todoState,
                onPresent: onPresent
            )
        }
    }
}

struct HomeFiltersPressureSection: View {
    @Binding var selectedPressureFilter: RoutineTaskPressure?
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Pressure",
            systemImage: "gauge.with.dots.needle.33percent",
            value: selectedPressureFilter?.title ?? "All",
            destination: .pressure,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersThinkingNeededSection: View {
    @Binding var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Thinking needed",
            systemImage: "brain.head.profile",
            value: selectedThinkingNeededFilter?.title ?? "All",
            destination: .thinkingNeeded,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersGoalSection: View {
    @Binding var selectedGoalFilter: HomeTaskGoalFilter
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Goal",
            systemImage: "target",
            value: selectedGoalFilter.title,
            destination: .goal,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersMediaSection: View {
    @Binding var selectedMediaFilter: TaskMediaFilter
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Media",
            systemImage: "paperclip",
            value: selectedMediaFilter.title,
            destination: .media,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersEstimationSection: View {
    @Binding var selectedEstimationFilter: TaskEstimationFilter
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Duration estimate",
            systemImage: "timer",
            value: selectedEstimationFilter.title,
            destination: .estimation,
            onPresent: onPresent
        )
    }
}

struct HomeFiltersImportanceUrgencySection: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let summary: String
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersDetailEntry(
            title: "Filter priority",
            systemImage: "line.3.horizontal.decrease.circle",
            value: selectionSummary
        ) {
            onPresent(.priority)
        }
        .accessibilityValue(selectionAccessibilityValue)
        .accessibilityHint("Open the importance and urgency filter")
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

struct HomeFiltersPriorityPickerSheet: View {
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
    let onPresent: (IOSFilterDetailDestination) -> Void

    var body: some View {
        HomeFiltersPickerEntry(
            title: "Place",
            systemImage: "mappin.and.ellipse",
            value: placeSummary,
            destination: .place,
            onPresent: onPresent
        )
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
