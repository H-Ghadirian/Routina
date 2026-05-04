import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailNotificationWarningPresentationTests {
    @Test
    func warningTextWaitsForLoadedTimedNotificationState() {
        #expect(
            TaskDetailNotificationWarningPresentation.warningText(
                hasLoadedNotificationStatus: false,
                expectsClockTimeNotification: true,
                appNotificationsEnabled: false,
                systemNotificationsAuthorized: false
            ) == nil
        )
        #expect(
            TaskDetailNotificationWarningPresentation.warningText(
                hasLoadedNotificationStatus: true,
                expectsClockTimeNotification: false,
                appNotificationsEnabled: false,
                systemNotificationsAuthorized: false
            ) == nil
        )
    }

    @Test
    func warningActionDistinguishesAppAndSystemSettings() {
        let appWarning = TaskDetailNotificationWarningPresentation.warningText(
            hasLoadedNotificationStatus: true,
            expectsClockTimeNotification: true,
            appNotificationsEnabled: false,
            systemNotificationsAuthorized: true
        )
        let systemWarning = TaskDetailNotificationWarningPresentation.warningText(
            hasLoadedNotificationStatus: true,
            expectsClockTimeNotification: true,
            appNotificationsEnabled: true,
            systemNotificationsAuthorized: false
        )

        #expect(appWarning?.contains("Routina") == true)
        #expect(systemWarning?.contains("system settings") == true)
        #expect(
            TaskDetailNotificationWarningPresentation.actionTitle(
                warningText: appWarning,
                appNotificationsEnabled: false
            ) == "Turn On Notifications"
        )
        #expect(
            TaskDetailNotificationWarningPresentation.actionTitle(
                warningText: systemWarning,
                appNotificationsEnabled: true
            ) == "Open System Settings"
        )
    }
}
