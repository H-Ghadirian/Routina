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
        HomeMacSharedFlagFiltersView(
            availableFlags: availableFlags,
            selectedFlags: selectedFlags,
            excludedFlags: excludedFlags,
            includeFlagMatchMode: includeFlagMatchMode,
            excludeFlagMatchMode: excludeFlagMatchMode,
            onSelectIncludedFlags: { updatedFlags in
                applySelectionChange(
                    from: selectedFlags,
                    to: updatedFlags,
                    onToggle: onToggleIncludedFlag
                )
            },
            onIncludeFlagMatchModeChange: onIncludeFlagMatchModeChange,
            onSelectExcludedFlags: { updatedFlags in
                applySelectionChange(
                    from: excludedFlags,
                    to: updatedFlags,
                    onToggle: onToggleExcludedFlag
                )
            },
            onExcludeFlagMatchModeChange: onExcludeFlagMatchModeChange
        )
    }

    private func applySelectionChange(
        from currentFlags: Set<String>,
        to updatedFlags: Set<String>,
        onToggle: (String) -> Void
    ) {
        guard let changedFlag = currentFlags.symmetricDifference(updatedFlags).first else { return }
        onToggle(changedFlag)
    }
}
