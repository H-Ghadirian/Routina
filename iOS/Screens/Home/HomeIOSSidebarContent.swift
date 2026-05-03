import SwiftUI

struct HomeIOSSidebarContent<EmptyContent: View, TaskListContent: View, ToolbarItems: ToolbarContent>: View {
    let isEmpty: Bool
    let navigationTitle: String
    let emptyContent: () -> EmptyContent
    let taskListContent: () -> TaskListContent
    let toolbarItems: () -> ToolbarItems

    init(
        isEmpty: Bool,
        navigationTitle: String,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        @ViewBuilder taskListContent: @escaping () -> TaskListContent,
        @ToolbarContentBuilder toolbarItems: @escaping () -> ToolbarItems
    ) {
        self.isEmpty = isEmpty
        self.navigationTitle = navigationTitle
        self.emptyContent = emptyContent
        self.taskListContent = taskListContent
        self.toolbarItems = toolbarItems
    }

    var body: some View {
        Group {
            if isEmpty {
                emptyContent()
            } else {
                taskListContent()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems() }
        .routinaHomeSidebarColumnWidth()
    }
}
