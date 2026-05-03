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
    let doneCount: Int
    let canceledCount: Int
    let routineCount: Int
    let todoCount: Int
    let boardOpenCount: Int
    let boardInProgressCount: Int
    let boardBlockedCount: Int
    let boardDoneCount: Int
    let isBoardBacklogScope: Bool
    let finishableSprints: [BoardSprint]
    let onFinishSprint: (UUID) -> Void

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
        ToolbarItemGroup(placement: .primaryAction) {
            finishSprintControl
            MacToolbarStatusBadge(
                title: "\(boardOpenCount) open",
                systemImage: "square.grid.3x3.topleft.filled",
                tintColor: .secondaryLabelColor
            )
            .help("Open todos in the current board view")

            MacToolbarStatusBadge(
                title: "\(boardInProgressCount) in progress",
                systemImage: "arrow.clockwise.circle.fill",
                tintColor: .systemBlue
            )
            .help("In-progress todos in the current board view")

            MacToolbarStatusBadge(
                title: "\(boardBlockedCount) blocked",
                systemImage: "exclamationmark.circle.fill",
                tintColor: .systemRed
            )
            .help("Blocked todos in the current board view")

            if !isBoardBacklogScope {
                MacToolbarStatusBadge(
                    title: "\(boardDoneCount) done",
                    systemImage: "checkmark.circle.fill",
                    tintColor: .systemGreen
                )
                .help("Done todos in the current board view")
            }
        }
    }

    @ToolbarContentBuilder
    private var goalsToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            MacGoalsNewGoalButton(store: goalsStore)
        }
    }

    @ToolbarContentBuilder
    private var standardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            MacToolbarStatusBadge(
                title: "\(doneCount) dones",
                systemImage: "checkmark.seal.fill",
                tintColor: .systemGreen
            )
            .help("\(doneCount) total dones")

            MacToolbarStatusBadge(
                title: "\(canceledCount) cancels",
                systemImage: "xmark.seal.fill",
                tintColor: .systemOrange
            )
            .help("\(canceledCount) total cancels")

            MacToolbarStatusBadge(
                title: "\(routineCount) routines",
                systemImage: "arrow.clockwise",
                tintColor: .secondaryLabelColor
            )
            .help("Total routines")

            MacToolbarStatusBadge(
                title: "\(todoCount) todos",
                systemImage: "checkmark.circle",
                tintColor: .secondaryLabelColor
            )
            .help("Total todos")
        }
    }

    @ViewBuilder
    private var finishSprintControl: some View {
        if finishableSprints.count == 1, let sprint = finishableSprints.first {
            Button {
                onFinishSprint(sprint.id)
            } label: {
                Label("Finish Sprint", systemImage: "flag.checkered")
            }
            .help("Finish \(sprint.title)")
        } else if finishableSprints.count > 1 {
            Menu {
                ForEach(finishableSprints) { sprint in
                    Button(sprint.title) {
                        onFinishSprint(sprint.id)
                    }
                }
            } label: {
                Label("Finish Sprint", systemImage: "flag.checkered")
            }
            .help("Finish an active sprint")
        }
    }
}

struct HomeMacBoardInspectorToolbarButton: View {
    let isPresented: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: isPresented ? "Hide Ticket Details" : "Show Ticket Details",
            systemImage: "sidebar.right"
        ) {
            onToggle()
        }
        .help(isPresented ? "Hide ticket details" : "Show ticket details")
    }
}
