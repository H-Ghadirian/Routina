import ComposableArchitecture
import Foundation
@testable @preconcurrency import Routina

@MainActor
func receiveTaskDetailNotificationStatus(
    _ store: TestStoreOf<HomeFeature>
) async {
    let isAlreadyLoaded = store.state.taskDetailState?.hasLoadedNotificationStatus == true
        && store.state.taskDetailState?.appNotificationsEnabled == false
        && store.state.taskDetailState?.systemNotificationsAuthorized == false
    if isAlreadyLoaded {
        await store.receive(.taskDetail(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false)))
    } else {
        await store.receive(.taskDetail(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false))) {
            $0.taskDetailState?.hasLoadedNotificationStatus = true
            $0.taskDetailState?.appNotificationsEnabled = false
            $0.taskDetailState?.systemNotificationsAuthorized = false
        }
    }
}
