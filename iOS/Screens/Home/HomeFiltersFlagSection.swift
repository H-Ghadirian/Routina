import SwiftUI

struct HomeFiltersFlagSection: View {
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    let data: HomeFlagFilterData
    let actions: HomeFlagFilterActions

    @ViewBuilder
    var body: some View {
        if data.hasFlags {
            Section("Flags") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Show tasks with")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        RoutinaGlassSegmentedControl(
                            accessibilityLabel: "Show tasks with flags",
                            options: RoutineTagMatchMode.allCases,
                            selection: $includeFlagMatchMode,
                            fillsAvailableWidth: true
                        ) { mode in
                            Text(mode.rawValue)
                        }
                        .frame(maxWidth: 180)
                    }

                    HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        if data.selectedFlags.isEmpty {
                            HomeFilterChipButton(title: "All Flags", isSelected: true) {
                                actions.onShowAllFlags()
                            }
                        } else {
                            ForEach(data.selectedFlags.sorted(), id: \.self) { flag in
                                HomeFilterChipButton(
                                    title: flag,
                                    isSelected: true,
                                    selectedColor: .accentColor
                                ) {
                                    actions.onToggleFlag(flag)
                                }
                            }
                        }
                    }

                    Text("Add more")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(data.visibleOptions.filter { !data.isSelected($0.name) }) { option in
                            HomeFilterChipButton(
                                title: "\(option.name) \(option.taskCount(for: data.taskListKind))",
                                isSelected: false
                            ) {
                                actions.onToggleFlag(option.name)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
