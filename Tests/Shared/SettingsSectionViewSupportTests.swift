import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct SettingsSectionViewSupportTests {
    @Test
    func visibleSectionsHideGitWhenFeatureIsDisabled() {
        #expect(!SettingsSectionID.visibleSections(isGitFeaturesEnabled: false).contains(.git))
        #expect(SettingsSectionID.visibleSections(isGitFeaturesEnabled: true).contains(.git))
    }

    @Test
    func rowPresentationBuildsNotificationSummary() {
        var state = SettingsFeatureState()
        state.notifications.notificationsEnabled = true
        state.notifications.notificationReminderTime = makeDate("2026-04-25T08:30:00Z")

        let presentation = SettingsSectionID.notifications.rowPresentation(in: state)

        #expect(presentation.subtitle.contains("Daily reminder"))
        #expect(presentation.value == "On")
    }

    @Test
    func rowPresentationBuildsGitSummaryFromConnectedServices() {
        var state = SettingsFeatureState()
        state.github.connectedRepository = GitHubRepositoryReference(owner: "openai", name: "codex")
        state.gitlab.hasSavedAccessToken = true
        state.gitlab.connectedUsername = "ghadirianh"

        let presentation = SettingsSectionID.git.rowPresentation(in: state)

        #expect(presentation.subtitle == "GitHub & GitLab connected")
        #expect(presentation.value == "Live")
    }
}
