import Foundation

struct HomeBoardState: Equatable {
    var todoDisplays: [HomeFeature.RoutineDisplay] = []
    var sprintBoardData: SprintBoardData = SprintBoardData()
    var selectedScope: HomeFeature.BoardScope = .backlog
}

struct HomeMacNavigationState: Equatable {
    var sidebarMode: HomeFeature.MacSidebarMode = .routines
    var sidebarSelection: HomeFeature.MacSidebarSelection? = nil
    var selectedSettingsSection: SettingsMacSection? = .notifications
}
