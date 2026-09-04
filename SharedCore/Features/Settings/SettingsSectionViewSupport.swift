import Foundation

enum SettingsSectionID: String, CaseIterable, Identifiable, Hashable {
    case general
    case devices
    case notifications
    case blocking
    case calendar
    case places
    case tags
    case flags
    case sections
    case appearance
    case iCloud
    case git
    case backup
    case quickAdd
    case shortcuts
    case aiConnections
    case support
    case about

    var id: String { rawValue }

    static func visibleSections(
        isGitFeaturesEnabled: Bool,
        isDevicesSectionEnabled: Bool = false,
        isPlacesEnabled: Bool = false
    ) -> [SettingsSectionID] {
        allCases.filter {
            isSectionVisible(
                $0,
                isGitFeaturesEnabled: isGitFeaturesEnabled,
                isDevicesSectionEnabled: isDevicesSectionEnabled,
                isPlacesEnabled: isPlacesEnabled
            )
        }
    }

    static func compactSectionGroups(
        isGitFeaturesEnabled: Bool,
        isDevicesSectionEnabled: Bool = false,
        isPlacesEnabled: Bool = false
    ) -> [[SettingsSectionID]] {
        let groupedSections: [[SettingsSectionID]] = [
            [
                .general,
                .devices,
                .notifications,
                .blocking,
                .calendar,
                .places,
                .tags,
                .flags,
                .sections,
                .appearance,
                .iCloud,
                .git,
                .quickAdd,
                .shortcuts,
                .aiConnections,
            ],
            [
                .about
            ],
        ]

        return
            groupedSections
            .map {
                $0.filter {
                    isSectionVisible(
                        $0,
                        isGitFeaturesEnabled: isGitFeaturesEnabled,
                        isDevicesSectionEnabled: isDevicesSectionEnabled,
                        isPlacesEnabled: isPlacesEnabled
                    )
                }
            }
            .filter { !$0.isEmpty }
    }

    private static func isSectionVisible(
        _ section: SettingsSectionID,
        isGitFeaturesEnabled: Bool,
        isDevicesSectionEnabled: Bool,
        isPlacesEnabled: Bool
    ) -> Bool {
        if section == .devices && !isDevicesSectionEnabled {
            return false
        }
        if section == .places && !isPlacesEnabled {
            return false
        }
        if section == .git && !isGitFeaturesEnabled {
            return false
        }
        #if !os(macOS) && !ROUTINA_IOS_FAMILY_CONTROLS
            if section == .blocking {
                return false
            }
        #endif
        #if !os(macOS)
            if section == .sections || section == .aiConnections {
                return false
            }
        #endif
        if section == .support {
            return false
        }
        if section == .backup {
            return false
        }

        return true
    }

    var resolvedNavigationSection: SettingsSectionID {
        switch self {
        case .support:
            return .about
        case .backup:
            return .iCloud
        default:
            return self
        }
    }

    private var content: SettingsContentCatalog.SectionContent {
        SettingsContentCatalog.shared.section(for: self)
    }

    var title: String {
        content.title
    }

    private var searchAliases: [String] {
        content.searchAliases
    }

    var searchDetailTerms: [String] {
        content.searchDetailTerms
    }

    var searchTerms: [String] {
        searchAliases + searchDetailTerms
    }

    func matchesSearch(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }
        let searchableText = ([title] + searchTerms).joined(separator: " ")
        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }

    /// Returns the concrete Settings concepts matched by a non-empty query.
    /// Aliases and category titles still filter destinations, but only these
    /// detail terms are shown as the explanatory result subtitle.
    func searchResultSubtitle(for query: String) -> String? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return nil }

        let matchedDetails = searchDetailTerms.filter {
            $0.localizedCaseInsensitiveContains(trimmedQuery)
        }
        guard !matchedDetails.isEmpty else { return nil }
        return "Matches: " + matchedDetails.joined(separator: " • ")
    }

    static func filteredSections(
        _ sections: [SettingsSectionID],
        matching query: String
    ) -> [SettingsSectionID] {
        sections.filter { $0.matchesSearch(query) }
    }

    static func filteredSectionGroups(
        _ groups: [[SettingsSectionID]],
        matching query: String
    ) -> [[SettingsSectionID]] {
        groups
            .map { filteredSections($0, matching: query) }
            .filter { !$0.isEmpty }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .devices: return "desktopcomputer.and.macbook"
        case .notifications: return "bell.badge.fill"
        case .blocking: return "lock.shield.fill"
        case .calendar: return "calendar.badge.plus"
        case .places: return "mappin.and.ellipse"
        case .tags: return "tag.fill"
        case .flags: return "flag.fill"
        case .sections: return "sidebar.leading"
        case .appearance: return "app.badge.fill"
        case .iCloud: return "icloud.fill"
        case .git: return "arrow.triangle.branch"
        case .backup: return "externaldrive.fill"
        case .quickAdd: return "text.badge.plus"
        case .shortcuts:
            #if os(macOS)
                return "keyboard.fill"
            #else
                return "square.grid.2x2.fill"
            #endif
        case .aiConnections: return "sparkles"
        case .support: return "envelope.fill"
        case .about: return "info.circle.fill"
        }
    }

    func rowPresentation(in state: SettingsFeatureState) -> SettingsSectionRowPresentation {
        switch self {
        case .general:
            return SettingsSectionRowPresentation(
                subtitle: "App Lock: \(state.appearance.isAppLockEnabled ? "On" : "Off") • Battery repeating tasks"
            )

        case .devices:
            return SettingsSectionRowPresentation(
                subtitle: state.devices.overviewSubtitle,
                value: state.devices.sessions.isEmpty ? nil : "\(state.devices.sessions.count)"
            )

        case .notifications:
            return SettingsSectionRowPresentation(
                subtitle: state.notifications.overviewSubtitle,
                value: state.notifications.notificationsEnabled ? "On" : "Off"
            )

        case .blocking:
            return SettingsSectionRowPresentation(
                subtitle: "Apps and websites across protected modes",
                value: "Modes"
            )

        case .calendar:
            return SettingsSectionRowPresentation(
                subtitle: state.appearance.calendarOverviewSubtitle,
                value: state.appearance.showPersianDates ? "Persian" : nil
            )

        case .places:
            return SettingsSectionRowPresentation()

        case .tags:
            return SettingsSectionRowPresentation()

        case .flags:
            return SettingsSectionRowPresentation(
                subtitle: "Built-in task behavior markers"
            )

        case .sections:
            return SettingsSectionRowPresentation(subtitle: "Custom task list sections and rules")

        case .appearance:
            return SettingsSectionRowPresentation(subtitle: state.appearance.overviewSubtitle)

        case .iCloud:
            return SettingsSectionRowPresentation(
                subtitle: dataContinuitySubtitle(in: state),
                value: dataContinuityValue(in: state)
            )

        case .git:
            guard state.appearance.isGitFeaturesEnabled else {
                return SettingsSectionRowPresentation(
                    subtitle: "GitHub and GitLab activity is hidden",
                    value: "Off"
                )
            }

            let ghConnected = state.github.connectedRepository != nil
            let glConnected = state.gitlab.isConnected
            let subtitle: String
            if ghConnected && glConnected {
                subtitle = "GitHub & GitLab connected"
            } else if glConnected {
                subtitle = state.gitlab.overviewSubtitle
            } else {
                subtitle = state.github.overviewSubtitle
            }

            return SettingsSectionRowPresentation(
                subtitle: subtitle,
                value: (ghConnected || glConnected) ? "Live" : nil
            )

        case .backup:
            return SettingsSectionRowPresentation(
                subtitle: dataContinuitySubtitle(in: state),
                value: dataContinuityValue(in: state)
            )

        case .quickAdd:
            return SettingsSectionRowPresentation(subtitle: "Supported syntax and examples")

        case .shortcuts:
            #if os(macOS)
                return SettingsSectionRowPresentation(subtitle: "Keyboard, Siri, and Apple Shortcuts")
            #else
                return SettingsSectionRowPresentation(subtitle: "Siri and Apple Shortcuts")
            #endif

        case .aiConnections:
            let isEnabled = SharedDefaults.app[.appSettingMacLocalAIAccessEnabled]
            return SettingsSectionRowPresentation(
                subtitle: "Read-only access for local AI clients",
                value: isEnabled ? "On" : "Off"
            )

        case .support:
            return SettingsSectionRowPresentation(subtitle: aboutAndSupportSubtitle(in: state))

        case .about:
            return SettingsSectionRowPresentation(subtitle: aboutAndSupportSubtitle(in: state))
        }
    }

    private func aboutAndSupportSubtitle(in state: SettingsFeatureState) -> String {
        "Email support • \(state.diagnostics.aboutOverviewSubtitle)"
    }

    private func dataContinuitySubtitle(in state: SettingsFeatureState) -> String {
        let cloudOperationIsInProgress = state.cloud.isCloudSyncInProgress
            || state.cloud.isCloudDataResetAuthenticationInProgress
            || state.cloud.isCloudDataResetInProgress
        let cloudNeedsStatus = !state.cloud.cloudStatusMessage.isEmpty || !state.cloud.cloudSyncAvailable
        if cloudOperationIsInProgress || cloudNeedsStatus {
            return state.cloud.overviewSubtitle
        }

        if state.dataTransfer.isDataTransferInProgress || !state.dataTransfer.dataTransferStatusMessage.isEmpty {
            return state.dataTransfer.overviewSubtitle
        }

        return "Sync, export, and import task data"
    }

    private func dataContinuityValue(in state: SettingsFeatureState) -> String? {
        if !state.cloud.cloudSyncAvailable {
            return "Off"
        }
        if state.cloud.isCloudSyncInProgress {
            return "Syncing"
        }
        if state.cloud.isCloudDataResetAuthenticationInProgress || state.cloud.isCloudDataResetInProgress {
            return "Reset"
        }
        if state.dataTransfer.isDataTransferInProgress {
            return "Backup"
        }
        return nil
    }
}

struct SettingsSectionRowPresentation: Equatable {
    var subtitle: String?
    var value: String?

    init(subtitle: String? = nil, value: String? = nil) {
        self.subtitle = subtitle
        self.value = value
    }
}
