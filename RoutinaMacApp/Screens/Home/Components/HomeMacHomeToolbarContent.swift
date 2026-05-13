import ComposableArchitecture
import SwiftUI

struct HomeMacHomeToolbarContent: ToolbarContent {
    enum Mode {
        case board
        case goals
        case standard
    }

    let mode: Mode
    let goalsStore: StoreOf<GoalsFeature>
    let showsDetailModePicker: Bool
    @Binding var detailMode: MacHomeDetailMode

    var body: some ToolbarContent {
        switch mode {
        case .board:
            boardToolbar
        case .goals:
            goalsToolbar
        case .standard:
            standardToolbar
        }
    }

    @ToolbarContentBuilder
    private var boardToolbar: some ToolbarContent {
        RoutinaMacSleepToolbarItem()
        detailModeToolbarItem
    }

    @ToolbarContentBuilder
    private var goalsToolbar: some ToolbarContent {
        RoutinaMacSleepToolbarItem()

        ToolbarItem(placement: .primaryAction) {
            MacGoalsNewGoalButton(store: goalsStore)
        }
    }

    @ToolbarContentBuilder
    private var standardToolbar: some ToolbarContent {
        RoutinaMacSleepToolbarItem()
        detailModeToolbarItem
    }

    @ToolbarContentBuilder
    private var detailModeToolbarItem: some ToolbarContent {
        if showsDetailModePicker {
            ToolbarItem(placement: .principal) {
                MacHomeDetailModePicker(selection: $detailMode)
            }
        }
    }
}

struct HomeMacBoardInspectorToolbarButton: View {
    let isPresented: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: isPresented ? "Hide Board Details" : "Show Board Details",
            systemImage: "sidebar.right"
        ) {
            onToggle()
        }
        .help(isPresented ? "Hide board details" : "Show board details")
    }
}
