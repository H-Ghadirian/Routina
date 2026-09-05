import Foundation

#if os(macOS)
    extension Notification.Name {
        static let routinaMacWebsiteBlockingStatusDidChange = Notification.Name(
            "RoutinaMacWebsiteBlockingStatusDidChange"
        )
    }

    struct MacWebsiteBlockingStatus: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case inactive
            case active
            case warning
        }

        var kind: Kind
        var message: String?

        static let inactive = MacWebsiteBlockingStatus(kind: .inactive, message: nil)
    }

    struct MacFocusBlockedApp: Codable, Equatable, Hashable, Identifiable, Sendable {
        var bundleIdentifier: String
        var displayName: String
        var bundlePath: String?
        var enabledModes: Set<ProtectionBlockingMode>

        var id: String { bundleIdentifier }

        init(
            bundleIdentifier: String,
            displayName: String,
            bundlePath: String?,
            enabledModes: Set<ProtectionBlockingMode> = ProtectionBlockingMode.defaultEnabledModes
        ) {
            self.bundleIdentifier = bundleIdentifier
            self.displayName = displayName
            self.bundlePath = bundlePath
            self.enabledModes = enabledModes
        }

        private enum CodingKeys: String, CodingKey {
            case bundleIdentifier
            case displayName
            case bundlePath
            case enabledModes
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
            displayName = try container.decode(String.self, forKey: .displayName)
            bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
            let decodedModes = try container.decodeIfPresent([ProtectionBlockingMode].self, forKey: .enabledModes)
            enabledModes = decodedModes.map(Set.init) ?? ProtectionBlockingMode.defaultEnabledModes
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
            try container.encode(displayName, forKey: .displayName)
            try container.encodeIfPresent(bundlePath, forKey: .bundlePath)
            try container.encode(
                ProtectionBlockingMode.allCases.filter { enabledModes.contains($0) },
                forKey: .enabledModes
            )
        }
    }

    extension FocusShieldSupport {
        static var isMacFocusAppBlockingEnabled: Bool {
            let defaultsKey = UserDefaultBoolValueKey.appSettingMacFocusAppBlockingEnabled.rawValue
            guard SharedDefaults.app.object(forKey: defaultsKey) != nil else {
                return true
            }

            return SharedDefaults.app[.appSettingMacFocusAppBlockingEnabled]
        }

        static func loadMacBlockedApps() -> [MacFocusBlockedApp] {
            guard let rawValue = SharedDefaults.app[.appSettingMacFocusBlockedApps],
                let data = rawValue.data(using: .utf8),
                let apps = try? JSONDecoder().decode([MacFocusBlockedApp].self, from: data)
            else {
                return []
            }

            return deduplicatedMacBlockedApps(apps)
        }

        static func saveMacBlockedApps(_ apps: [MacFocusBlockedApp]) {
            let deduplicatedApps = deduplicatedMacBlockedApps(apps)
            guard let data = try? JSONEncoder().encode(deduplicatedApps),
                let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }

            SharedDefaults.app[.appSettingMacFocusBlockedApps] = rawValue
        }

        static func macBlockedApp(from url: URL) -> MacFocusBlockedApp? {
            guard let bundle = Bundle(url: url),
                let bundleIdentifier = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                !bundleIdentifier.isEmpty
            else {
                return nil
            }

            let displayName =
                (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return MacFocusBlockedApp(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName.isEmpty ? bundleIdentifier : displayName,
                bundlePath: url.path
            )
        }

        static func macBlockedAppsSummaryText(_ apps: [MacFocusBlockedApp]) -> String {
            switch apps.count {
            case 0:
                return "No apps selected"
            case 1:
                return "1 app selected"
            default:
                return "\(apps.count) apps selected"
            }
        }

        private static func deduplicatedMacBlockedApps(_ apps: [MacFocusBlockedApp]) -> [MacFocusBlockedApp] {
            var seenBundleIDs: Set<String> = []
            var result: [MacFocusBlockedApp] = []

            for app in apps {
                let bundleIdentifier = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !bundleIdentifier.isEmpty,
                    !seenBundleIDs.contains(bundleIdentifier)
                else {
                    continue
                }

                seenBundleIDs.insert(bundleIdentifier)
                result.append(
                    MacFocusBlockedApp(
                        bundleIdentifier: bundleIdentifier,
                        displayName: app.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? bundleIdentifier
                            : app.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        bundlePath: app.bundlePath,
                        enabledModes: app.enabledModes
                    )
                )
            }

            return result.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }
#endif
