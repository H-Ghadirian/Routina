import Foundation

struct SprintFocusAllocationDraft: Equatable, Identifiable {
    var taskID: UUID
    var minutes: Int

    var id: UUID { taskID }
}

struct HomeBoardState: Equatable {
    var todoDisplays: [HomeFeature.RoutineDisplay] = []
    var sprintBoardData: SprintBoardData = SprintBoardData()
    var selectedScope: HomeFeature.BoardScope = .backlog
    var creatingBacklogTitle: String? = nil
    var creatingSprintTitle: String? = nil
    var renamingSprintID: UUID? = nil
    var renamingSprintTitle: String = ""
    var deletingSprintID: UUID? = nil
    var sprintFocusAllocationSessionID: UUID? = nil
    var sprintFocusAllocationDrafts: [SprintFocusAllocationDraft] = []
}

struct HomeMacNavigationState: Equatable {
    var sidebarMode: HomeFeature.MacSidebarMode = .routines
    var sidebarSelection: HomeFeature.MacSidebarSelection? = nil
    var selectedSettingsSection: SettingsMacSection? = .notifications
}
