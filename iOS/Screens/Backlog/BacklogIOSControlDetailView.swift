import ComposableArchitecture
import SwiftUI

struct BacklogIOSControlDetailView: View {
    let store: StoreOf<BacklogFeature>
    let destination: BacklogIOSControlDestination

    private var bindings: BacklogIOSFilterBindings {
        BacklogIOSFilterBindings(store: store)
    }

    @ViewBuilder
    var body: some View {
        switch destination {
        case .taskType:
            HomeFiltersDetailSheet(title: "Task Type") {
                Section {
                    Picker("Task type", selection: bindings.binding(\.taskListMode)) {
                        ForEach(HomeTaskListMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .created:
            HomeFiltersDetailSheet(title: "Created") {
                Section {
                    Picker("Created", selection: bindings.binding(\.createdDateFilter)) {
                        ForEach(HomeTaskCreatedDateFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .due:
            HomeFiltersDetailSheet(title: "Due") {
                Section {
                    Picker("Due", selection: bindings.binding(\.dueDateFilter)) {
                        ForEach(BacklogDueDateFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("Due uses one-time deadlines and active repeating Due schedules.")
                }
            }
        case .todoState:
            HomeFiltersDetailSheet(title: "One-time State") {
                Section {
                    Picker("One-time state", selection: bindings.binding(\.selectedTodoState)) {
                        Label("Any state", systemImage: "square.grid.2x2")
                            .tag(Optional<TodoState>.none)

                        ForEach(TodoState.filterableCases) { state in
                            Label(state.displayTitle, systemImage: state.systemImage)
                                .tag(Optional(state))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .importance:
            HomeFiltersImportancePickerSheet(
                selectedImportanceUrgencyFilter: bindings.binding(
                    \.selectedImportanceUrgencyFilter
                )
            )
        case .urgency:
            HomeFiltersUrgencyPickerSheet(
                selectedImportanceUrgencyFilter: bindings.binding(
                    \.selectedImportanceUrgencyFilter
                )
            )
        case .pressure:
            HomeFiltersDetailSheet(title: "Pressure") {
                Section {
                    Picker("Pressure", selection: bindings.binding(\.selectedPressureFilter)) {
                        ForEach(pressureOptions, id: \.self) { pressure in
                            Text(pressure?.title ?? "All").tag(pressure)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("All does not filter by pressure. Other choices set the minimum pressure.")
                }
            }
        case .thinkingNeeded:
            HomeFiltersDetailSheet(title: "Thinking Needed") {
                Section {
                    Picker(
                        "Thinking needed",
                        selection: bindings.binding(\.selectedThinkingNeededFilter)
                    ) {
                        ForEach(thinkingNeededOptions, id: \.self) { level in
                            Text(level?.title ?? "All").tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("All does not filter by thinking needed; other choices are exact.")
                }
            }
        case .estimation:
            HomeFiltersDetailSheet(title: "Duration Estimate") {
                Section {
                    Picker(
                        "Duration estimate",
                        selection: bindings.binding(\.selectedEstimationFilter)
                    ) {
                        ForEach(TaskEstimationFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .media:
            HomeFiltersDetailSheet(title: "Media") {
                Section {
                    Picker("Media", selection: bindings.binding(\.selectedMediaFilter)) {
                        ForEach(TaskMediaFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        case .tags:
            HomeTagFilterPickerSheet(
                data: tagFilterData,
                bindings: HomeTagRuleBindings(
                    includeTagMatchMode: bindings.binding(\.includeTagMatchMode),
                    excludeTagMatchMode: bindings.binding(\.excludeTagMatchMode)
                ),
                actions: tagFilterActions,
                labels: HomeTagFilterPickerLabels(
                    navigationTitle: "Filter Backlog Tags",
                    includeFooter: "Select tags to include in Backlog.",
                    excludeFooter: "Select tags to hide from Backlog."
                )
            )
        case .flags:
            BacklogIOSFlagFilterPicker(store: store)
        case .sort:
            HomeFiltersDetailSheet(title: "Task Order") {
                Section {
                    Picker("Task order", selection: bindings.binding(\.sortOrder)) {
                        ForEach(BacklogSortOrder.allCases) { order in
                            Label(order.title, systemImage: order.systemImage).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("Tasks without a due boundary stay at the end in either due-date order.")
                }
            }
        }
    }

    private var pressureOptions: [RoutineTaskPressure?] {
        [nil] + RoutineTaskPressure.allCases.map(Optional.some)
    }

    private var thinkingNeededOptions: [RoutineTaskThinkingNeeded?] {
        [nil] + RoutineTaskThinkingNeeded.allCases.map(Optional.some)
    }

    private var tagFilterData: HomeTagFilterData {
        let summaries = store.presentation.filterCatalog.tags.map { tag in
            RoutineTagSummary(
                name: tag,
                linkedRoutineCount: store.presentation.filterCatalog.tagCounts[
                    RoutineTag.normalized(tag) ?? tag,
                    default: 0
                ],
                colorHex: RoutineTagColors.colorHex(for: tag, in: store.tagColors)
            )
        }
        return HomeTagFilterData(
            selectedTags: store.filters.selectedTags,
            excludedTags: store.filters.excludedTags,
            tagSummaries: summaries,
            allTagTaskCount: store.presentation.taskCount,
            suggestedRelatedTags: [],
            availableExcludeTagSummaries: summaries
        )
    }

    private var tagFilterActions: HomeTagFilterActions {
        HomeTagFilterActions(
            onShowAllTags: {
                bindings.update(\.selectedTags, to: [])
            },
            onToggleIncludedTag: { tag in
                let mutation = HomeTagFilterMutationSupport.toggledIncludedTag(
                    tag,
                    selectedTags: store.filters.selectedTags,
                    suggestionAnchor: nil
                )
                bindings.update(\.selectedTags, to: mutation.selectedTags)
            },
            onAddIncludedTag: { tag in
                let mutation = HomeTagFilterMutationSupport.toggledIncludedTag(
                    tag,
                    selectedTags: store.filters.selectedTags,
                    suggestionAnchor: nil
                )
                bindings.update(\.selectedTags, to: mutation.selectedTags)
            },
            onToggleExcludedTag: { tag in
                let mutation = HomeTagFilterMutationSupport.toggledExcludedTag(
                    tag,
                    selectedTags: store.filters.selectedTags,
                    excludedTags: store.filters.excludedTags
                )
                bindings.update { filters in
                    filters.selectedTags = mutation.selectedTags
                    filters.excludedTags = mutation.excludedTags
                }
            }
        )
    }
}
