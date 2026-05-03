import ComposableArchitecture
@testable @preconcurrency import Routina

@MainActor
func receiveNotificationStatusLoaded(_ store: TestStoreOf<TaskDetailFeature>) async {
    await store.receive(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false)) {
        $0.hasLoadedNotificationStatus = true
        $0.appNotificationsEnabled = false
        $0.systemNotificationsAuthorized = false
    }
}
