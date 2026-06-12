import Foundation

struct HomeMacNavigationSnapshot: Equatable {
    var sidebarMode: HomeFeature.MacSidebarMode
    var sidebarSelection: HomeFeature.MacSidebarSelection?
    var selectedTaskID: UUID?
    var selectedSettingsSection: SettingsMacSection
    var selectedBoardScope: HomeFeature.BoardScope
    var detailMode: MacHomeDetailMode
    var progressMode: MacHomeProgressMode

    init(
        sidebarMode: HomeFeature.MacSidebarMode,
        sidebarSelection: HomeFeature.MacSidebarSelection?,
        selectedTaskID: UUID?,
        selectedSettingsSection: SettingsMacSection?,
        selectedBoardScope: HomeFeature.BoardScope,
        detailMode: MacHomeDetailMode,
        progressMode: MacHomeProgressMode = .stats
    ) {
        self.sidebarMode = sidebarMode
        self.sidebarSelection = sidebarSelection
        self.selectedTaskID = Self.normalizedSelectedTaskID(
            sidebarSelection: sidebarSelection,
            selectedTaskID: selectedTaskID
        )
        self.selectedSettingsSection = sidebarMode == .settings
            ? selectedSettingsSection ?? .notifications
            : .notifications
        self.selectedBoardScope = selectedBoardScope
        self.detailMode = detailMode.visibleSurfaceMode
        self.progressMode = progressMode.visibleSurfaceMode
    }

    private static func normalizedSelectedTaskID(
        sidebarSelection: HomeFeature.MacSidebarSelection?,
        selectedTaskID: UUID?
    ) -> UUID? {
        guard case let .task(taskID) = sidebarSelection else {
            return selectedTaskID
        }
        return taskID
    }
}

struct HomeMacNavigationHistory: Equatable {
    private(set) var backStack: [HomeMacNavigationSnapshot] = []
    private(set) var current: HomeMacNavigationSnapshot?
    private(set) var forwardStack: [HomeMacNavigationSnapshot] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    mutating func record(_ snapshot: HomeMacNavigationSnapshot) {
        guard current != snapshot else { return }

        if let current {
            backStack.append(current)
        }
        current = snapshot
        forwardStack.removeAll()
    }

    mutating func replaceCurrent(_ snapshot: HomeMacNavigationSnapshot) {
        current = snapshot
    }

    mutating func goBack(from liveSnapshot: HomeMacNavigationSnapshot) -> HomeMacNavigationSnapshot? {
        recordLiveSnapshotIfNeeded(liveSnapshot)
        guard let previous = backStack.popLast(), let current else { return nil }

        forwardStack.append(current)
        self.current = previous
        return previous
    }

    mutating func goForward(from liveSnapshot: HomeMacNavigationSnapshot) -> HomeMacNavigationSnapshot? {
        recordLiveSnapshotIfNeeded(liveSnapshot)
        guard let next = forwardStack.popLast(), let current else { return nil }

        backStack.append(current)
        self.current = next
        return next
    }

    private mutating func recordLiveSnapshotIfNeeded(_ liveSnapshot: HomeMacNavigationSnapshot) {
        guard current != liveSnapshot else { return }

        if let current {
            backStack.append(current)
        }
        current = liveSnapshot
        forwardStack.removeAll()
    }
}
