import SwiftUI

struct HomeMacStatsFlagFilterSection: View {
    let availableFlags: [String]
    let selectedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludedFlags: Set<String>
    let excludeFlagMatchMode: RoutineTagMatchMode
    let onIncludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onExcludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleIncludedFlag: (String) -> Void
    let onToggleExcludedFlag: (String) -> Void

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Flag filters",
            summaryText: summaryText,
            systemImage: "flag.fill",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 16) {
                flagRule(
                    title: "Show stats with",
                    mode: includeFlagMatchMode,
                    selectedFlags: selectedFlags,
                    systemImage: "flag.fill",
                    tint: .accentColor,
                    onModeChange: onIncludeFlagMatchModeChange,
                    onToggle: onToggleIncludedFlag
                )

                flagRule(
                    title: "Hide stats with",
                    mode: excludeFlagMatchMode,
                    selectedFlags: excludedFlags,
                    systemImage: "flag.slash.fill",
                    tint: .red,
                    onModeChange: onExcludeFlagMatchModeChange,
                    onToggle: onToggleExcludedFlag
                )
            }
        }
    }

    private var summaryText: String {
        let activeCount = selectedFlags.count + excludedFlags.count
        guard activeCount > 0 else {
            return "\(availableFlags.count) \(availableFlags.count == 1 ? "flag" : "flags") available"
        }
        return "\(activeCount) active \(activeCount == 1 ? "filter" : "filters")"
    }

    private func flagRule(
        title: String,
        mode: RoutineTagMatchMode,
        selectedFlags: Set<String>,
        systemImage: String,
        tint: Color,
        onModeChange: @escaping (RoutineTagMatchMode) -> Void,
        onToggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: title,
                options: RoutineTagMatchMode.allCases,
                selection: Binding(get: { mode }, set: onModeChange),
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.rawValue)
            }

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                if selectedFlags.isEmpty {
                    Text(title.hasPrefix("Hide") ? "No flags selected" : "All flags included")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectedFlags.sorted(), id: \.self) { flag in
                        flagChip(
                            flag,
                            systemImage: systemImage,
                            tint: tint,
                            isSelected: true,
                            action: { onToggle(flag) }
                        )
                    }
                }
            }

            HomeMacStatsSectionTitle("Add flags")

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableFlags.filter { flag in
                    !StatsFlagFilterMutationSupport.contains(flag, in: selectedFlags)
                }, id: \.self) { flag in
                    flagChip(
                        flag,
                        systemImage: systemImage,
                        tint: tint,
                        isSelected: false,
                        action: { onToggle(flag) }
                    )
                }
            }
        }
    }

    private func flagChip(
        _ flag: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(flag, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? tint : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .routinaGlassPill(tint: tint, tintOpacity: isSelected ? 0.16 : 0.08, interactive: true)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
