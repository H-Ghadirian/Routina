import ComposableArchitecture
import SwiftUI

struct TaskRankingMacControlsDetailView: View {
    @State private var selectedTab: HomeMacFilterDetailTab = .filter
    @AppStorage(
        UserDefaultStringValueKey.appSettingTaskLadderTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var taskRowHiddenFieldsRawValue = HomeTaskRowVisibility.taskLadderDefaultStorageRawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

    let store: StoreOf<TaskRankingFeature>
    let onNewContainerGroup: () -> Void
    let onUseRepeatingTaskAsGroup: () -> Void

    var body: some View {
        HomeMacFilterDetailContainerView(
            title: "Task Ladder Controls",
            showsTitle: false
        ) {
            header
            HomeMacFilterDetailTabStrip(
                selection: $selectedTab,
                accessibilityLabel: "Task Ladder tabs",
                title: tabTitle
            )

            switch selectedTab {
            case .filter:
                viewTabContent
            case .sort:
                sortTabContent
            case .appearance:
                appearanceTabContent
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Task Ladder")
                    .font(.title2.weight(.semibold))

                Text("View, sorting, and appearance affect Task Ladder only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(itemCountLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button("Reset") {
                resetControls()
            }
            .disabled(!hasNonDefaultControls)
        }
    }

    private var viewTabContent: some View {
        Group {
            HomeMacSidebarSectionCard(title: "View") {
                VStack(alignment: .leading, spacing: 18) {
                    HomeMacAdaptiveFilterControlRow("Rank by") {
                        HomeMacAdaptiveFilterChoiceControl(
                            accessibilityLabel: "Task Ladder metric",
                            options: TaskRankingMetric.allCases,
                            selection: metricBinding,
                            minimumSegmentWidth: 120,
                            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                        ) { metric in
                            Text(metric.title)
                        }
                    }

                    if store.metric.supportsTemporalWeight {
                        HomeMacAdaptiveFilterControlRow("Values") {
                            HomeMacAdaptiveFilterChoiceControl(
                                accessibilityLabel: "Task Ladder values",
                                options: TaskRankingValueMode.allCases,
                                selection: valueModeBinding,
                                minimumSegmentWidth: 100,
                                compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                            ) { mode in
                                Text(mode.title)
                            }
                        }

                        Text("Base shows saved values. Now applies each repeating task’s due-date rule.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            actionsCard
        }
    }

    private var sortTabContent: some View {
        HomeMacSidebarSectionCard(title: "Sorting") {
            VStack(alignment: .leading, spacing: 12) {
                HomeMacAdaptiveFilterControlRow("Order") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Task Ladder order",
                        options: [false, true],
                        selection: reversedBinding,
                        minimumSegmentWidth: 132,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { isReversed in
                        Label(
                            store.metric.directionTitle(isReversed: isReversed),
                            systemImage: isReversed ? "arrow.up" : "arrow.down"
                        )
                    }
                }

                Text(sortExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Task Ladder Row") {
            HomeMacFilterAppearanceToggleRow(
                "Multiline Titles",
                subtitle: "Wrap long task titles onto additional lines.",
                isOn: taskRowMultilineTitlesBinding
            )

            ForEach(taskRowFields) { field in
                HomeMacFilterAppearanceToggleRow(
                    appearanceTitle(for: field),
                    subtitle: appearanceSubtitle(for: field),
                    isOn: taskRowFieldVisibilityBinding(field)
                )
            }

            Text("Shown: \(taskRowSummaryText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsCard: some View {
        HomeMacSidebarSectionCard(title: "Actions") {
            VStack(spacing: 10) {
                Menu {
                    Button("New Container Group…", action: onNewContainerGroup)
                    Button("Use Repeating Task as Group…", action: onUseRepeatingTaskAsGroup)
                        .disabled(!canUseRepeatingTaskAsGroup)
                } label: {
                    actionLabel("Add Group", systemImage: "folder.badge.plus")
                }
                .menuStyle(.borderlessButton)
                .help("Create a container group or use a repeating task as a group")

                Button {
                    store.send(.refresh)
                } label: {
                    actionLabel("Refresh Task Ladder", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
            }
        }
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tabTitle(_ tab: HomeMacFilterDetailTab) -> String {
        tab == .filter ? "View" : tab.title
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

    private var sortExplanation: String {
        store.metric.supportsManualLadder
            ? "Direction changes the presentation and Move Up/Down meaning without rewriting the saved values."
            : "Estimated time is factual and read only; direction changes only which estimates appear first."
    }

    private var canUseRepeatingTaskAsGroup: Bool {
        store.tasks.contains {
            !$0.isOneOffTask && store.presentation.eligibleTaskIDs.contains($0.id)
        }
    }

    private var itemCountLabel: String {
        if HomeTaskSearchIndex.query(store.searchText) != nil {
            let count = store.searchPresentation.matches.count
            return count == 1 ? "1 match" : "\(count) matches"
        }
        let count = store.presentation.taskCount
        return count == 1 ? "1 item" : "\(count) items"
    }

    private var taskRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: taskRowHiddenFieldsRawValue)
    }

    private var taskRowFields: [HomeTaskRowField] {
        HomeTaskRowField.taskLadderAppearanceFields(showsPlaces: isPlacesEnabled)
    }

    private var taskRowSummaryText: String {
        let visibleCount = taskRowFields.lazy.filter { taskRowVisibility.shows($0) }.count
        return visibleCount == taskRowFields.count
            ? "All fields"
            : "\(visibleCount) of \(taskRowFields.count) fields"
    }

    private var taskRowMultilineTitlesBinding: Binding<Bool> {
        Binding(
            get: { taskRowVisibility.allowsMultilineTitles },
            set: { persistTaskRowVisibility(taskRowVisibility.settingMultilineTitles($0)) }
        )
    }

    private func taskRowFieldVisibilityBinding(_ field: HomeTaskRowField) -> Binding<Bool> {
        Binding(
            get: { taskRowVisibility.shows(field) },
            set: { persistTaskRowVisibility(taskRowVisibility.setting(field, visible: $0)) }
        )
    }

    private func persistTaskRowVisibility(_ visibility: HomeTaskRowVisibility) {
        taskRowHiddenFieldsRawValue = visibility.storageRawValue ?? ""
        AppSettingsPersistenceMirror.schedule()
    }

    private func resetControls() {
        store.send(.metricChanged(.pressure))
        store.send(.valueModeChanged(.base))
        store.send(.reversedMetricsChanged([]))
        persistTaskRowVisibility(.taskLadderDefaultValue)
    }

    private var hasNonDefaultControls: Bool {
        store.hasNonDefaultWorkspaceControls
            || taskRowVisibility != .taskLadderDefaultValue
    }

    private func appearanceTitle(for field: HomeTaskRowField) -> String {
        field == .taskTypeBadge ? "Repeating Badge" : field.title
    }

    private func appearanceSubtitle(for field: HomeTaskRowField) -> String? {
        field == .taskTypeBadge ? "Marks repeating tasks without labelling ordinary one-time tasks." : field.subtitle
    }
}
