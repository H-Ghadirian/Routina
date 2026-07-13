import SwiftUI

struct HomeMacTaskListModeStripView: View {
    let selectedMode: HomeFeature.TaskListMode
    let onSelectMode: (HomeFeature.TaskListMode) -> Void

    var body: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Task list mode",
            options: Self.displayModes,
            selection: selectedMode,
            onSelect: onSelectMode,
            minimumSegmentWidth: 72,
            fillsAvailableWidth: true
        ) { mode in
            Text(mode.title)
                .accessibilityLabel(mode.accessibilityLabel)
                .help(mode.title)
        }
    }

    private static let displayModes: [HomeFeature.TaskListMode] = [
        .all,
        .todos,
        .routines,
        .records
    ]
}
