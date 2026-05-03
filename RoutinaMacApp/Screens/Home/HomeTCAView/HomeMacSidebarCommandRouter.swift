import SwiftUI

struct HomeMacSidebarCommandRouter<Content: View>: View {
    let content: Content
    let mode: HomeFeature.MacSidebarMode
    let onOpenRoutines: () -> Void
    let onOpenAddTask: () -> Void
    let onOpenQuickAdd: () -> Void
    let onOpenTimeline: () -> Void
    let onOpenStats: () -> Void
    let onModeChanged: (HomeFeature.MacSidebarMode) -> Void

    init(
        content: Content,
        mode: HomeFeature.MacSidebarMode,
        onOpenRoutines: @escaping () -> Void,
        onOpenAddTask: @escaping () -> Void,
        onOpenQuickAdd: @escaping () -> Void,
        onOpenTimeline: @escaping () -> Void,
        onOpenStats: @escaping () -> Void,
        onModeChanged: @escaping (HomeFeature.MacSidebarMode) -> Void
    ) {
        self.content = content
        self.mode = mode
        self.onOpenRoutines = onOpenRoutines
        self.onOpenAddTask = onOpenAddTask
        self.onOpenQuickAdd = onOpenQuickAdd
        self.onOpenTimeline = onOpenTimeline
        self.onOpenStats = onOpenStats
        self.onModeChanged = onModeChanged
    }

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenRoutinesInSidebar)) { _ in
                onOpenRoutines()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAddTask)) { _ in
                onOpenAddTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenQuickAdd)) { _ in
                onOpenQuickAdd()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenTimelineInSidebar)) { _ in
                onOpenTimeline()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenStatsInSidebar)) { _ in
                onOpenStats()
            }
            .onChange(of: mode) { _, mode in
                onModeChanged(mode)
            }
    }
}
