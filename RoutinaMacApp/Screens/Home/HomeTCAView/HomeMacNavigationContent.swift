import SwiftUI

struct HomeMacNavigationContent<
    SidebarContent: View,
    BoardCenterContent: View,
    BoardInspectorContent: View,
    GoalsDetailContent: View,
    MainDetailContent: View,
    BoardToolbarContent: ToolbarContent
>: View {
    let isBoardMode: Bool
    let isGoalsMode: Bool
    let boardNavigationTitle: String
    let mainNavigationTitle: String
    let addEditFormCoordinator: AddEditFormCoordinator
    @Binding var isBoardInspectorPresented: Bool
    let sidebarContent: () -> SidebarContent
    let boardCenterContent: () -> BoardCenterContent
    let boardInspectorContent: () -> BoardInspectorContent
    let goalsDetailContent: () -> GoalsDetailContent
    let mainDetailContent: () -> MainDetailContent
    let boardToolbarContent: () -> BoardToolbarContent

    init(
        isBoardMode: Bool,
        isGoalsMode: Bool,
        boardNavigationTitle: String,
        mainNavigationTitle: String,
        isBoardInspectorPresented: Binding<Bool>,
        addEditFormCoordinator: AddEditFormCoordinator,
        @ViewBuilder sidebarContent: @escaping () -> SidebarContent,
        @ViewBuilder boardCenterContent: @escaping () -> BoardCenterContent,
        @ViewBuilder boardInspectorContent: @escaping () -> BoardInspectorContent,
        @ViewBuilder goalsDetailContent: @escaping () -> GoalsDetailContent,
        @ViewBuilder mainDetailContent: @escaping () -> MainDetailContent,
        @ToolbarContentBuilder boardToolbarContent: @escaping () -> BoardToolbarContent
    ) {
        self.isBoardMode = isBoardMode
        self.isGoalsMode = isGoalsMode
        self.boardNavigationTitle = boardNavigationTitle
        self.mainNavigationTitle = mainNavigationTitle
        self._isBoardInspectorPresented = isBoardInspectorPresented
        self.addEditFormCoordinator = addEditFormCoordinator
        self.sidebarContent = sidebarContent
        self.boardCenterContent = boardCenterContent
        self.boardInspectorContent = boardInspectorContent
        self.goalsDetailContent = goalsDetailContent
        self.mainDetailContent = mainDetailContent
        self.boardToolbarContent = boardToolbarContent
    }

    var body: some View {
        Group {
            if isBoardMode {
                boardNavigation
            } else if isGoalsMode {
                goalsNavigation
            } else {
                mainNavigation
            }
        }
    }

    private var boardNavigation: some View {
        NavigationSplitView {
            sidebarContent()
        } detail: {
            HStack(spacing: 0) {
                boardCenterContent()
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)

                if isBoardInspectorPresented {
                    boardInspectorContent()
                        .frame(width: 400)
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .leading) {
                            Divider()
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .navigationTitle(boardNavigationTitle)
            .toolbar { boardToolbarContent() }
            .animation(.easeInOut(duration: 0.22), value: isBoardInspectorPresented)
            .environment(\.addEditFormCoordinator, addEditFormCoordinator)
        }
    }

    private var goalsNavigation: some View {
        NavigationSplitView {
            sidebarContent()
        } detail: {
            goalsDetailContent()
        }
    }

    private var mainNavigation: some View {
        NavigationSplitView {
            sidebarContent()
        } detail: {
            mainDetailContent()
                .navigationTitle(mainNavigationTitle)
                .environment(\.addEditFormCoordinator, addEditFormCoordinator)
        }
    }
}
