import AppKit
import SwiftUI

private final class HomeMacCommandWindowNumberNSView: NSView {
    var onWindowNumberChanged: ((Int?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        notifyWindowNumberChanged()
    }

    func notifyWindowNumberChanged() {
        let windowNumber = window?.windowNumber
        DispatchQueue.main.async { [weak self] in
            self?.onWindowNumberChanged?(windowNumber)
        }
    }
}

private struct HomeMacCommandWindowNumberView: NSViewRepresentable {
    let onWindowNumberChanged: (Int?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HomeMacCommandWindowNumberNSView(frame: .zero)
        view.onWindowNumberChanged = onWindowNumberChanged
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let windowNumberView = nsView as? HomeMacCommandWindowNumberNSView {
            windowNumberView.onWindowNumberChanged = onWindowNumberChanged
            windowNumberView.notifyWindowNumberChanged()
        }
    }
}

struct HomeMacSidebarCommandRouter<Content: View>: View {
    @State private var commandWindowNumber: Int?

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
    let onScrollSelectedTaskInSidebar: () -> Void
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
        onScrollSelectedTaskInSidebar: @escaping () -> Void,
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
        self.onScrollSelectedTaskInSidebar = onScrollSelectedTaskInSidebar
        self.onModeChanged = onModeChanged
    }

    var body: some View {
        content
            .background(
                HomeMacCommandWindowNumberView { windowNumber in
                    guard commandWindowNumber != windowNumber else { return }
                    commandWindowNumber = windowNumber
                }
                .allowsHitTesting(false)
            )
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
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacScrollSelectedTaskInSidebar)) { notification in
                guard shouldHandleCommandNotification(notification) else { return }
                onScrollSelectedTaskInSidebar()
            }
            .onChange(of: mode) { _, mode in
                onModeChanged(mode)
            }
    }

    private func shouldHandleCommandNotification(_ notification: Notification) -> Bool {
        if let sourceWindowNumber = RoutinaMacCommandNotification.sourceWindowNumber(from: notification) {
            guard let commandWindowNumber else {
                if let activeWindowNumber = NSApp.keyWindow?.windowNumber ?? NSApp.mainWindow?.windowNumber {
                    return activeWindowNumber == sourceWindowNumber
                }
                return true
            }
            return sourceWindowNumber == commandWindowNumber
        }

        guard let keyWindowNumber = NSApp.keyWindow?.windowNumber,
              let commandWindowNumber else {
            return true
        }
        return keyWindowNumber == commandWindowNumber
    }
}
