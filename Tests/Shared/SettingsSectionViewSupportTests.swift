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
    func generalSectionAppearsFirstWithBatteryRoutineSummary() {
        var state = SettingsFeatureState()
        state.appearance.isAppLockEnabled = true
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: false)

        #expect(sections.first == .general)
        #expect(SettingsSectionID.general.title == "General")
        #expect(SettingsSectionID.general.rowPresentation(in: state) == SettingsSectionRowPresentation(
            subtitle: "App Lock: On • Battery routines"
        ))
    }

    @Test
    func visibleSectionsHideGitWhenFeatureIsDisabled() {
        #expect(!SettingsSectionID.visibleSections(isGitFeaturesEnabled: false).contains(.git))
        #expect(SettingsSectionID.visibleSections(isGitFeaturesEnabled: true).contains(.git))
        #expect(!SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: false).flatMap { $0 }.contains(.git))
        #expect(SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: true).flatMap { $0 }.contains(.git))
    }

    @Test
    func visibleSectionsHideMergedSupportSection() {
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: false)
        let compactSections = SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: false).flatMap { $0 }

        #expect(!sections.contains(.support))
        #expect(!compactSections.contains(.support))
        #expect(sections.contains(.about))
        #expect(SettingsSectionID.about.title == "Support & About")
    }

    @Test
    func compactSectionsIncludeShortcuts() {
        let compactSections = SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: false).flatMap { $0 }

        #expect(compactSections.contains(.shortcuts))
        #expect(SettingsSectionID.shortcuts.title == "Shortcuts")
        #expect(SettingsSectionID.shortcuts.rowPresentation(in: SettingsFeatureState()) == SettingsSectionRowPresentation(
            subtitle: "Keyboard, Siri, and Apple Shortcuts"
        ))
    }

    @Test
    func compactSectionsIncludeBlocking() {
        let compactSections = SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: false).flatMap { $0 }

        #expect(compactSections.contains(.blocking))
        #expect(SettingsSectionID.blocking.title == "Blocking")
        #expect(SettingsSectionID.blocking.rowPresentation(in: SettingsFeatureState()) == SettingsSectionRowPresentation(
            subtitle: "Apps and websites across protected modes",
            value: "Modes"
        ))
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
    func rowPresentationBuildsCalendarSummaryFromPlannerTimelinePreference() {
        var state = SettingsFeatureState()
        state.appearance.showsTimelineTasksInDayPlanner = false
        state.appearance.showPersianDates = true

        let presentation = SettingsSectionID.calendar.rowPresentation(in: state)

        #expect(presentation.subtitle == "Timeline badges • Persian dates")
        #expect(presentation.value == "Persian")
    }

    @Test
    func rowPresentationBuildsGitSummaryFromConnectedServices() {
        var state = SettingsFeatureState()
        state.appearance.isGitFeaturesEnabled = true
        state.github.connectedRepository = GitHubRepositoryReference(owner: "openai", name: "codex")
        state.gitlab.hasSavedAccessToken = true
        state.gitlab.connectedUsername = "ghadirianh"

        let presentation = SettingsSectionID.git.rowPresentation(in: state)

        #expect(presentation.subtitle == "GitHub & GitLab connected")
        #expect(presentation.value == "Live")
    }

    @Test
    func rowPresentationBuildsGitDisabledSummary() {
        let presentation = SettingsSectionID.git.rowPresentation(in: SettingsFeatureState())

        #expect(presentation.subtitle == "GitHub and GitLab activity is hidden")
        #expect(presentation.value == "Off")
    }

    @Test
    func rowPresentationBuildsMergedAboutSummary() {
        var state = SettingsFeatureState()
        state.diagnostics.appVersion = "1.2.3"

        let presentation = SettingsSectionID.about.rowPresentation(in: state)

        #expect(presentation.subtitle.contains("Email support"))
        #expect(presentation.subtitle.contains("Version 1.2.3"))
    }
}
