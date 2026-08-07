import SwiftUI

struct HomeMacRoutineFlagFiltersView: View {
    let includeFlagMatchMode: Binding<RoutineTagMatchMode>
    let data: HomeFlagFilterData
    let actions: HomeFlagFilterActions

    var body: some View {
        if data.hasFlags {
            VStack(alignment: .leading, spacing: 8) {
                Text("Show tasks with flags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Show tasks with flags",
                    options: RoutineTagMatchMode.allCases,
                    selection: includeFlagMatchMode,
                    fillsAvailableWidth: true
                ) { mode in
                    Text(mode.rawValue)
                }

                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    if data.selectedFlags.isEmpty {
                        HomeMacTagChipView(
                            title: "All Flags",
                            count: data.visibleOptions.reduce(0) { $0 + $1.taskCount(for: data.taskListKind) },
                            systemImage: "flag.slash.fill",
                            isSelected: true,
                            action: actions.onShowAllFlags
                        )
                    } else {
                        ForEach(data.selectedFlags.sorted(), id: \.self) { flag in
                            HomeMacTagChipView(
                                title: flag,
                                count: data.taskCount(for: flag),
                                systemImage: "flag.fill",
                                isSelected: true,
                                action: { actions.onToggleFlag(flag) }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transaction { transaction in
                    transaction.animation = nil
                }

                let availableFlags = data.visibleOptions.filter { !data.isSelected($0.name) }
                if !availableFlags.isEmpty {
                    Text("Add more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(availableFlags) { option in
                            HomeMacTagChipView(
                                title: option.name,
                                count: option.taskCount(for: data.taskListKind),
                                systemImage: "flag.fill",
                                isSelected: false,
                                action: { actions.onToggleFlag(option.name) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
        }
    }
}
