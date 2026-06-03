import ComposableArchitecture
import SwiftUI

struct HomeMacHomeToolbarContent: ToolbarContent {
    enum Mode {
        case board
        case goals
        case standard
    }

    let mode: Mode
    let showsDetailModePicker: Bool
    let showsProgressModePicker: Bool
    @Binding var detailMode: MacHomeDetailMode
    @Binding var progressMode: MacHomeProgressMode
    let onPlaceCheckInMapRequested: (PlaceCheckInActivity?) -> Void

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
        navigationToolbarItems
        detailModeToolbarItem
    }

    @ToolbarContentBuilder
    private var goalsToolbar: some ToolbarContent {
        navigationToolbarItems
    }

    @ToolbarContentBuilder
    private var standardToolbar: some ToolbarContent {
        navigationToolbarItems
        detailModeToolbarItem
    }

    @ToolbarContentBuilder
    private var navigationToolbarItems: some ToolbarContent {
        RoutinaMacPlaceCheckInToolbarItem(onMapRequested: onPlaceCheckInMapRequested)
    }

    @ToolbarContentBuilder
    private var detailModeToolbarItem: some ToolbarContent {
        if showsDetailModePicker {
            ToolbarItem(placement: .principal) {
                MacHomeDetailModePicker(selection: $detailMode)
            }
        } else if showsProgressModePicker {
            ToolbarItem(placement: .principal) {
                MacHomeProgressModePicker(selection: $progressMode)
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
