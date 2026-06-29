import SwiftUI

struct HomeMacSidebarCommandRouter<Content: View>: View {
    let content: Content
    let mode: HomeFeature.MacSidebarMode
    let onOpenRoutines: () -> Void
    let onOpenAddTask: () -> Void
    let onOpenAddEvent: () -> Void
    let onOpenAddEmotion: () -> Void
    let onOpenAddNote: () -> Void
    let onOpenAddGoal: () -> Void
    let onOpenCheckIn: () -> Void
    let onOpenAway: () -> Void
    let onOpenTimeline: () -> Void
    let onOpenStats: () -> Void
    let onModeChanged: (HomeFeature.MacSidebarMode) -> Void

    init(
        content: Content,
        mode: HomeFeature.MacSidebarMode,
        onOpenRoutines: @escaping () -> Void,
        onOpenAddTask: @escaping () -> Void,
        onOpenAddEvent: @escaping () -> Void,
        onOpenAddEmotion: @escaping () -> Void,
        onOpenAddNote: @escaping () -> Void,
        onOpenAddGoal: @escaping () -> Void,
        onOpenCheckIn: @escaping () -> Void,
        onOpenAway: @escaping () -> Void,
        onOpenTimeline: @escaping () -> Void,
        onOpenStats: @escaping () -> Void,
        onModeChanged: @escaping (HomeFeature.MacSidebarMode) -> Void
    ) {
        self.content = content
        self.mode = mode
        self.onOpenRoutines = onOpenRoutines
        self.onOpenAddTask = onOpenAddTask
        self.onOpenAddEvent = onOpenAddEvent
        self.onOpenAddEmotion = onOpenAddEmotion
        self.onOpenAddNote = onOpenAddNote
        self.onOpenAddGoal = onOpenAddGoal
        self.onOpenCheckIn = onOpenCheckIn
        self.onOpenAway = onOpenAway
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
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAddEvent)) { _ in
                onOpenAddEvent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAddEmotion)) { _ in
                onOpenAddEmotion()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAddNote)) { _ in
                onOpenAddNote()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAddGoal)) { _ in
                onOpenAddGoal()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenCheckIn)) { _ in
                onOpenCheckIn()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAway)) { _ in
                onOpenAway()
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
