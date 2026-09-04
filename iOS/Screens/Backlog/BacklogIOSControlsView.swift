import ComposableArchitecture
import SwiftUI

enum BacklogIOSControlTab: String, CaseIterable, Identifiable {
    case filter = "Filter"
    case sort = "Sort"

    var id: Self { self }
}

enum BacklogIOSControlDestination: String, Identifiable {
    case taskType
    case created
    case due
    case todoState
    case importance
    case urgency
    case pressure
    case thinkingNeeded
    case estimation
    case media
    case tags
    case flags
    case sort

    var id: String { rawValue }
}

struct BacklogIOSControlsView: View {
    let store: StoreOf<BacklogFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = BacklogIOSControlTab.filter
    @State private var presentedDetail: BacklogIOSControlDestination?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Backlog controls", selection: $selectedTab) {
                        ForEach(BacklogIOSControlTab.allCases) { tab in
                            Text(tabTitle(tab)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(backlogCountLabel)
                }

                switch selectedTab {
                case .filter:
                    filterControls
                case .sort:
                    sortControls
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Backlog Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(resetTitle, action: resetSelectedTab)
                        .disabled(!canResetSelectedTab)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $presentedDetail) { destination in
            BacklogIOSControlDetailView(
                store: store,
                destination: destination
            )
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var filterControls: some View {
        Group {
            Section("Tasks") {
                controlEntry(
                    "Task type",
                    systemImage: "checklist",
                    value: store.filters.taskListMode.title,
                    destination: .taskType
                )
                controlEntry(
                    "Created",
                    systemImage: "calendar",
                    value: store.filters.createdDateFilter.title,
                    destination: .created
                )
                controlEntry(
                    "Due",
                    systemImage: "calendar.badge.clock",
                    value: store.filters.dueDateFilter.title,
                    destination: .due
                )
                if store.filters.taskListMode != .routines {
                    controlEntry(
                        "One-time state",
                        systemImage: "checkmark.circle",
                        value: store.filters.selectedTodoState?.displayTitle ?? "All",
                        destination: .todoState
                    )
                }
            }

            Section("Priority") {
                controlEntry(
                    "Importance",
                    systemImage: "star.fill",
                    value: minimumImportanceSummary,
                    destination: .importance
                )
                controlEntry(
                    "Urgency",
                    systemImage: "clock.badge.exclamationmark",
                    value: minimumUrgencySummary,
                    destination: .urgency
                )
                controlEntry(
                    "Pressure",
                    systemImage: "gauge.with.dots.needle.33percent",
                    value: store.filters.selectedPressureFilter?.title ?? "All",
                    destination: .pressure
                )
                controlEntry(
                    "Thinking needed",
                    systemImage: "brain.head.profile",
                    value: store.filters.selectedThinkingNeededFilter?.title ?? "All",
                    destination: .thinkingNeeded
                )
            }

            Section("Context") {
                controlEntry(
                    "Duration estimate",
                    systemImage: "timer",
                    value: store.filters.selectedEstimationFilter.title,
                    destination: .estimation
                )
                controlEntry(
                    "Media",
                    systemImage: "paperclip",
                    value: store.filters.selectedMediaFilter.title,
                    destination: .media
                )
            }

            Section("Organization") {
                controlEntry(
                    "Filter tags",
                    systemImage: "tag",
                    value: ruleSummary(
                        included: store.filters.selectedTags,
                        excluded: store.filters.excludedTags,
                        emptyTitle: "All tags",
                        prefix: "#"
                    ),
                    destination: .tags,
                    allowsMultilineValue: true
                )
                controlEntry(
                    "Filter flags",
                    systemImage: "flag",
                    value: ruleSummary(
                        included: RoutineFlag.iOSVisible(store.filters.selectedFlags),
                        excluded: RoutineFlag.iOSVisible(store.filters.excludedFlags),
                        emptyTitle: "All flags"
                    ),
                    destination: .flags,
                    allowsMultilineValue: true
                )
            }
        }
    }

    private var sortControls: some View {
        Section {
            controlEntry(
                "Task order",
                systemImage: "arrow.up.arrow.down",
                value: store.filters.sortOrder.title,
                destination: .sort
            )
        } header: {
            Text("Sorting")
        } footer: {
            Text("Ordering applies inside each Backlog section without changing its hierarchy.")
        }
    }

    private func controlEntry(
        _ title: String,
        systemImage: String,
        value: String,
        destination: BacklogIOSControlDestination,
        allowsMultilineValue: Bool = false
    ) -> some View {
        HomeFiltersDetailEntry(
            title: title,
            systemImage: systemImage,
            value: value,
            allowsMultilineValue: allowsMultilineValue
        ) {
            presentedDetail = destination
        }
    }

    private func tabTitle(_ tab: BacklogIOSControlTab) -> String {
        switch tab {
        case .filter:
            return store.filters.hasNonDefaultFilters ? "Filter •" : tab.rawValue
        case .sort:
            return store.filters.hasNonDefaultSortOrder ? "Sort •" : tab.rawValue
        }
    }

    private var backlogCountLabel: String {
        let count = store.presentation.taskCount
        return count == 1 ? "1 task currently shown." : "\(count) tasks currently shown."
    }

    private var resetTitle: String {
        selectedTab == .filter ? "Reset Filters" : "Reset Sort"
    }

    private var canResetSelectedTab: Bool {
        switch selectedTab {
        case .filter:
            return store.filters.hasNonDefaultFilters
        case .sort:
            return store.filters.hasNonDefaultSortOrder
        }
    }

    private func resetSelectedTab() {
        switch selectedTab {
        case .filter:
            store.send(.filtersChanged(store.filters.resettingFilters()))
        case .sort:
            store.send(.filtersChanged(store.filters.resettingSortOrder()))
        }
    }

    private var minimumImportanceSummary: String {
        guard let importance = store.filters.selectedImportanceUrgencyFilter?.minimumImportance else {
            return "All"
        }
        return "\(importance.title)+"
    }

    private var minimumUrgencySummary: String {
        guard let urgency = store.filters.selectedImportanceUrgencyFilter?.minimumUrgency else {
            return "All"
        }
        return "\(urgency.title)+"
    }

    private func ruleSummary(
        included: Set<String>,
        excluded: Set<String>,
        emptyTitle: String,
        prefix: String = ""
    ) -> String {
        let summaries = [
            namedRuleSummary(excluded, action: "Hiding", prefix: prefix),
            namedRuleSummary(included, action: "Showing", prefix: prefix),
        ].compactMap { $0 }
        return summaries.isEmpty ? emptyTitle : summaries.joined(separator: " • ")
    }

    private func namedRuleSummary(
        _ values: Set<String>,
        action: String,
        prefix: String
    ) -> String? {
        let names = values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard !names.isEmpty else { return nil }
        return "\(action) \(names.map { prefix + $0 }.joined(separator: ", "))"
    }
}

@MainActor
struct BacklogIOSFilterBindings {
    let store: StoreOf<BacklogFeature>

    func binding<Value: Equatable & Sendable>(
        _ keyPath: WritableKeyPath<BacklogFilterState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.filters[keyPath: keyPath] },
            set: { update(keyPath, to: $0) }
        )
    }

    func update<Value: Equatable & Sendable>(
        _ keyPath: WritableKeyPath<BacklogFilterState, Value>,
        to value: Value
    ) {
        guard store.filters[keyPath: keyPath] != value else { return }
        var filters = store.filters
        filters[keyPath: keyPath] = value
        store.send(.filtersChanged(filters))
    }

    func update(_ mutation: (inout BacklogFilterState) -> Void) {
        var filters = store.filters
        mutation(&filters)
        guard filters != store.filters else { return }
        store.send(.filtersChanged(filters))
    }
}
