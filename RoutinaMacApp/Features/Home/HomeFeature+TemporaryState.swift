import Foundation

extension HomeFeature {
    func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        let restoredState = HomeFeatureTemporaryViewStateSupport.applyBase(
            persistedState,
            to: &state,
            defaultHideUnavailableRoutines: appSettingsClient.hideUnavailableRoutines()
        )

        if let rawValue = restoredState.macSidebarModeRawValue, let mode = MacSidebarMode(rawValue: rawValue) {
            state.macSidebarMode = normalizedMacSidebarMode(mode)
        }
        if let rawValue = restoredState.macSelectedSettingsSectionRawValue {
            state.selectedSettingsSection =
                SettingsMacSection(rawValue: rawValue)?
                .resolvedNavigationSection
        }

        if let rawValue = restoredState.taskListModeRawValue, let mode = TaskListMode(rawValue: rawValue) {
            state.taskListMode = mode
        }
    }

    func persistTemporaryViewState(_ state: State) {
        let persistedMacSidebarMode =
            state.macSidebarMode == .addTask
            ? state.navigation.addTaskReturnMode ?? .routines
            : normalizedMacSidebarMode(state.macSidebarMode)
        appSettingsClient.setTemporaryViewState(
            HomeFeatureTemporaryViewStateSupport.makeTemporaryViewState(
                from: state,
                existing: appSettingsClient.temporaryViewState(),
                macSidebarModeRawValue: persistedMacSidebarMode.rawValue,
                macSelectedSettingsSectionRawValue: state.selectedSettingsSection?.rawValue
            )
        )
    }

    private func normalizedMacSidebarMode(_ mode: MacSidebarMode) -> MacSidebarMode {
        switch mode {
        case .board, .addTask:
            return .routines
        case .adventure:
            return .adventure
        case .routines, .goals, .timeline, .stats, .backlog, .taskLadder, .settings:
            return mode
        }
    }
}
