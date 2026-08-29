import Foundation
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
    func cloudUsageHidesCategoriesWhoseFeaturesAreUnavailable() {
        let visibility = SettingsCloudUsageVisibility(
            isPlacesEnabled: false,
            isGoalsEnabled: false,
            areEventEmotionActionsEnabled: false,
            isNotesEnabled: false
        )

        #expect(visibility.shows(.tasks))
        #expect(visibility.shows(.logs))
        #expect(visibility.shows(.images))
        #expect(!visibility.shows(.places))
        #expect(!visibility.shows(.goals))
        #expect(!visibility.shows(.emotions))
        #expect(!visibility.shows(.events))
        #expect(!visibility.shows(.notes))
        #expect(!visibility.shows(.voiceNotes))
    }

    @Test
    func cloudUsageShowsAvailableFeatureCategories() {
        let visibility = SettingsCloudUsageVisibility(
            isPlacesEnabled: true,
            isGoalsEnabled: true,
            areEventEmotionActionsEnabled: true,
            isNotesEnabled: true
        )

        #expect(visibility.shows(.places))
        #expect(visibility.shows(.goals))
        #expect(visibility.shows(.emotions))
        #expect(visibility.shows(.events))
        #expect(visibility.shows(.notes))
        #expect(visibility.shows(.voiceNotes))
    }

    @Test
    func backupStatusHidesItsDefaultInstructionButKeepsOperationFeedback() {
        var state = SettingsDataTransferState()

        #expect(!state.shouldShowStatusText)
        #expect(state.statusText == "Export a full backup package, or import a package or legacy JSON file.")

        state.isDataTransferInProgress = true
        #expect(state.shouldShowStatusText)

        state.isDataTransferInProgress = false
        state.dataTransferStatusMessage = "Saved to Routina.routinabackup."
        #expect(state.shouldShowStatusText)
    }

    @Test
    func cloudSyncProgressShowsTheLatestReceivedItemCount() {
        var state = SettingsCloudState(
            cloudSyncAvailable: true,
            isCloudSyncInProgress: true,
            cloudStatusMessage: "Receiving iCloud data… 76 items."
        )

        #expect(state.syncStatusText == "Receiving iCloud data… 76 items.")
        #expect(state.overviewSubtitle == "Receiving iCloud data… 76 items.")

        state.cloudStatusMessage = "Applying 76 iCloud items…"
        #expect(state.syncStatusText == "Applying 76 iCloud items…")
    }

    @Test
    func cloudSyncViewsUseLinearProgressBars() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let expectations = [
            (
                path: "iOS/Screens/Settings/SettingsCloudDetailView.swift",
                statusNeedle: "store.cloud.syncStatusText"
            ),
            (
                path: "RoutinaMacApp/Screens/Settings/SettingsMacDataSupportDetailViews.swift",
                statusNeedle: "store.cloud.syncStatusText"
            ),
            (
                path: "iOS/Screens/Home/HomeTCAViewPlatform.swift",
                statusNeedle: "manualCloudRefreshStatusText"
            ),
            (
                path: "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift",
                statusNeedle: "manualCloudRefreshStatusText"
            )
        ]

        for expectation in expectations {
            let source = try String(
                contentsOf: projectRoot.appendingPathComponent(expectation.path),
                encoding: .utf8
            )
            #expect(
                source.contains(".progressViewStyle(.linear)"),
                "Missing sync progress bar in \(expectation.path)"
            )
            #expect(
                source.contains(expectation.statusNeedle),
                "Missing live sync status in \(expectation.path)"
            )
        }
    }

    @Test
    func generalSectionAppearsFirstWithBatteryRoutineSummary() {
        var state = SettingsFeatureState()
        state.appearance.isAppLockEnabled = true
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: false)

        #expect(sections.first == .general)
        #expect(SettingsSectionID.general.title == "General")
        #expect(SettingsSectionID.general.rowPresentation(in: state) == SettingsSectionRowPresentation(
            subtitle: "App Lock: On • Battery repeating tasks"
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
    func settingsSearchMatchesTitlesAndStableAliases() {
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: true)

        #expect(SettingsSectionID.filteredSections(sections, matching: "backlog") == [.sections])
        #expect(SettingsSectionID.filteredSections(sections, matching: "sync") == [.iCloud])
        #expect(SettingsSectionID.filteredSections(sections, matching: "flags") == [.flags])
        #expect(SettingsSectionID.filteredSections(sections, matching: "no such setting").isEmpty)
        #expect(SettingsSectionID.filteredSections(sections, matching: "   ") == sections)
        #expect(SettingsSectionID.flags.searchResultSubtitle(for: "hide") ==
            "Matches: Hide from Task Lists • Hide from Calendar List • Hide from Timeline • Hide from Task Ladder")
        #expect(SettingsSectionID.flags.searchResultSubtitle(for: "flags") == nil)
    }

    @Test
    func compactSettingsKeepsSearchCloseToTheDestinationList() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("iOS/Screens/Settings/SettingsIOSViews.swift"),
            encoding: .utf8
        )

        #expect(source.contains(".contentMargins(.top, 0, for: .scrollContent)"))
    }

    @Test
    func visibleSectionsHideDevicesWhenFeatureIsDisabled() {
        #expect(!SettingsSectionID.visibleSections(
            isGitFeaturesEnabled: false
        ).contains(.devices))
        #expect(SettingsSectionID.visibleSections(
            isGitFeaturesEnabled: false,
            isDevicesSectionEnabled: true
        ).contains(.devices))
        #expect(!SettingsSectionID.compactSectionGroups(
            isGitFeaturesEnabled: false
        ).flatMap { $0 }.contains(.devices))
        #expect(SettingsSectionID.compactSectionGroups(
            isGitFeaturesEnabled: false,
            isDevicesSectionEnabled: true
        ).flatMap { $0 }.contains(.devices))
    }

    @Test
    func visibleSectionsHidePlacesWhenFeatureIsDisabled() {
        #expect(!SettingsSectionID.visibleSections(
            isGitFeaturesEnabled: false
        ).contains(.places))
        #expect(SettingsSectionID.visibleSections(
            isGitFeaturesEnabled: false,
            isPlacesEnabled: true
        ).contains(.places))
        #expect(!SettingsSectionID.compactSectionGroups(
            isGitFeaturesEnabled: false
        ).flatMap { $0 }.contains(.places))
        #expect(SettingsSectionID.compactSectionGroups(
            isGitFeaturesEnabled: false,
            isPlacesEnabled: true
        ).flatMap { $0 }.contains(.places))
    }

    @Test
    func placesAndTagsRowsDoNotShowSubtitles() {
        let state = SettingsFeatureState()

        #expect(SettingsSectionID.places.rowPresentation(in: state).subtitle == nil)
        #expect(SettingsSectionID.tags.rowPresentation(in: state).subtitle == nil)
    }

    @Test
    func sectionsRowAppearsOnMacWithRulesSummary() {
        #if os(macOS)
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: false)
        let compactSections = SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: false).flatMap { $0 }

        #expect(sections.contains(.sections))
        #expect(compactSections.contains(.sections))
        #expect(SettingsSectionID.sections.rowPresentation(in: SettingsFeatureState()) == SettingsSectionRowPresentation(
            subtitle: "Custom task list sections and rules"
        ))
        #endif
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
    func visibleSectionsHideMergedBackupSection() {
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: false)
        let compactSections = SettingsSectionID.compactSectionGroups(isGitFeaturesEnabled: false).flatMap { $0 }

        #expect(!sections.contains(.backup))
        #expect(!compactSections.contains(.backup))
        #expect(sections.contains(.iCloud))
        #expect(SettingsSectionID.iCloud.title == "iCloud & Backup")
        #expect(SettingsSectionID.backup.resolvedNavigationSection == .iCloud)
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
    func aiConnectionsSectionIsAvailableOnlyOnMac() {
        let sections = SettingsSectionID.visibleSections(isGitFeaturesEnabled: false)
        #if os(macOS)
        #expect(sections.contains(.aiConnections))
        #expect(SettingsSectionID.aiConnections.title == "AI Connections")
        #expect(SettingsSectionID.aiConnections.rowPresentation(in: SettingsFeatureState()).subtitle == "Read-only access for local AI clients")
        #else
        #expect(!sections.contains(.aiConnections))
        #endif
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

        #expect(presentation.subtitle?.contains("Daily reminder") == true)
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

        #expect(presentation.subtitle?.contains("Email support") == true)
        #expect(presentation.subtitle?.contains("Version 1.2.3") == true)
    }

    @Test
    func rowPresentationBuildsMergedDataContinuitySummary() {
        var state = SettingsFeatureState()
        state.cloud.cloudSyncAvailable = true

        let presentation = SettingsSectionID.iCloud.rowPresentation(in: state)

        #expect(presentation.subtitle == "Sync, export, and import task data")
        #expect(presentation.value == nil)
    }

    @Test
    func dataTransferBackupFreshnessUsesTwentyFourHourWindow() {
        let now = makeDate("2026-06-06T12:00:00Z")
        var state = SettingsDataTransferState(
            lastSuccessfulBackupDate: now.addingTimeInterval(-23 * 60 * 60)
        )

        #expect(state.hasRecentSuccessfulBackup(referenceDate: now))
        #expect(state.cloudResetBackupRequirementText(referenceDate: now).contains("Recent verified backup saved"))

        state.lastSuccessfulBackupDate = now.addingTimeInterval(-25 * 60 * 60)

        #expect(!state.hasRecentSuccessfulBackup(referenceDate: now))
        #expect(state.cloudResetBackupRequirementText(referenceDate: now).contains("within the last 24 hours"))
    }
}
