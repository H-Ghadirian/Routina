import ComposableArchitecture
import SwiftUI

enum TaskRankingIOSControlTab: String, CaseIterable, Identifiable {
    case view = "View"
    case sort = "Sort"

    var id: Self { self }
}

struct TaskRankingIOSControlsView: View {
    let store: StoreOf<TaskRankingFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: TaskRankingIOSControlTab

    init(
        store: StoreOf<TaskRankingFeature>,
        initialTab: TaskRankingIOSControlTab = .view
    ) {
        self.store = store
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Task Ladder controls", selection: $selectedTab) {
                        ForEach(TaskRankingIOSControlTab.allCases) { tab in
                            Text(tabTitle(tab)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(itemCountLabel)
                }

                switch selectedTab {
                case .view:
                    viewControls
                case .sort:
                    sortControls
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Task Ladder Controls")
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var viewControls: some View {
        Group {
            Section {
                Picker("Rank by", selection: metricBinding) {
                    ForEach(TaskRankingMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .pickerStyle(.inline)

                if store.metric.supportsTemporalWeight {
                    Picker("Values", selection: valueModeBinding) {
                        ForEach(TaskRankingValueMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Ranking")
            } footer: {
                if store.metric.supportsTemporalWeight {
                    Text("Base shows saved values. Now applies each repeating task’s due-date rule.")
                }
            }
        }
    }

    private var sortControls: some View {
        Section {
            Picker("Order", selection: reversedBinding) {
                ForEach([false, true], id: \.self) { isReversed in
                    Label(
                        store.metric.directionTitle(isReversed: isReversed),
                        systemImage: isReversed ? "arrow.up" : "arrow.down"
                    )
                    .tag(isReversed)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Sorting")
        } footer: {
            Text(sortExplanation)
        }
    }

    private var metricBinding: Binding<TaskRankingMetric> {
        Binding(
            get: { store.metric },
            set: { store.send(.metricChanged($0)) }
        )
    }

    private var valueModeBinding: Binding<TaskRankingValueMode> {
        Binding(
            get: { store.valueMode },
            set: { store.send(.valueModeChanged($0)) }
        )
    }

    private var reversedBinding: Binding<Bool> {
        Binding(
            get: { store.isReversed },
            set: { isReversed in
                guard store.isReversed != isReversed else { return }
                store.send(.directionToggled)
            }
        )
    }

    private func tabTitle(_ tab: TaskRankingIOSControlTab) -> String {
        switch tab {
        case .view:
            return hasNonDefaultView ? "View •" : tab.rawValue
        case .sort:
            return hasNonDefaultSort ? "Sort •" : tab.rawValue
        }
    }

    private var itemCountLabel: String {
        let count = store.presentation.taskCount
        return count == 1 ? "1 item currently shown." : "\(count) items currently shown."
    }

    private var resetTitle: String {
        selectedTab == .view ? "Reset View" : "Reset Sort"
    }

    private var canResetSelectedTab: Bool {
        selectedTab == .view ? hasNonDefaultView : hasNonDefaultSort
    }

    private var hasNonDefaultView: Bool {
        store.hasNonDefaultViewControls
    }

    private var hasNonDefaultSort: Bool {
        store.hasNonDefaultSortControls
    }

    private func resetSelectedTab() {
        switch selectedTab {
        case .view:
            store.send(.metricChanged(.pressure))
            store.send(.valueModeChanged(.base))
        case .sort:
            store.send(.reversedMetricsChanged([]))
        }
    }

    private var sortExplanation: String {
        store.metric.supportsManualLadder
            ? "Order changes the presentation and Move Up/Down meaning without rewriting saved values."
            : "Estimated time is factual and read only; order changes which estimates appear first."
    }
}
