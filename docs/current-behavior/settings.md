# Settings Current Behavior

This page summarizes active Settings, durable preference, backup, reset, App Lock, and build-entry behavior.

## Key Decisions

- [0165](../decisions/0165-suggest-backup-before-cloud-data-reset.md)
- [0166](../decisions/0166-use-app-lock-for-cloud-data-reset.md)
- [0167](../decisions/0167-merge-icloud-and-backup-settings.md)
- [0168](../decisions/0168-require-recent-backup-for-cloud-data-reset.md)
- [0170](../decisions/0170-treat-backup-reset-as-complete-user-data-operations.md)
- [0210](../decisions/0210-store-durable-preferences-in-swiftdata.md)
- [0235](../decisions/0235-require-authentication-to-disable-app-lock.md)
- [0237](../decisions/0237-hide-settings-devices-behind-beta-toggle.md)
- [0238](../decisions/0238-use-project-local-mac-dev-run-entrypoint.md)
- [0241](../decisions/0241-gate-settings-reset-with-app-lock.md)
- [0248](../decisions/0248-add-explicit-mac-prod-run-entrypoint.md)
- [0257](../decisions/0257-hide-task-sharing-behind-beta-toggle.md)
- [0258](../decisions/0258-hide-linked-task-visualizer-behind-beta-toggle.md)
- [0275](../decisions/0275-hide-places-behind-beta-toggle.md)
- [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md)
- [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
- [0284](../decisions/0284-hide-filter-query-sections-behind-beta-toggle.md)
- [0290](../decisions/0290-limit-free-active-tasks-behind-subscription.md)
- [0293](../decisions/0293-add-settings-unlimited-task-override-while-products-unavailable.md)
- [0313](../decisions/0313-disable-mac-app-widgets-in-app-targets.md)
- [0374](../decisions/0374-move-unlimited-task-override-to-beta-experiments.md)
- [0464](../decisions/0464-host-mac-settings-in-a-standard-window.md)
- [0465](../decisions/0465-prepare-mac-development-app-for-screenshots.md)
- [0466](../decisions/0466-harden-app-store-release-surfaces.md)
- [0467](../decisions/0467-declare-exempt-encryption-in-production-bundles.md)
- [0470](../decisions/0470-keep-beta-experiments-out-of-production.md)
- [0513](../decisions/0513-defer-ios-screen-time-blocking-until-distribution-approval.md)
- [0514](../decisions/0514-defer-ios-location-services-until-places-release.md)
- [0515](../decisions/0515-report-signed-cloudkit-environment-in-diagnostics.md)
- [0516](../decisions/0516-make-support-diagnostics-copyable.md)
- [0517](../decisions/0517-sandbox-embedded-mcp-helper.md)
- [0518](../decisions/0518-scope-signed-cloudkit-diagnostics-to-macos.md)
- [0525](../decisions/0525-gate-testflight-archives-on-cloudkit-schema-deployment.md)
- [0526](../decisions/0526-identify-exact-builds-in-support.md)

## Current Contract

- User-owned preferences that should back up, restore, reset, and sync belong in SwiftData.
- The standalone Mac Settings surface uses a launch-suppressed, single-instance standard window. It retains the system Settings command and Command-comma routing while supporting minimize, free resizing and zoom above its 640 by 560 minimum, and native full screen.
- Purchase entitlement is resolved from StoreKit rather than backed up in user data. Weekly, monthly, annual, and lifetime products unlock unlimited active tasks. The paywall shows renewal disclosure plus Privacy Policy and Terms of Use links, and Support & About exposes the same legal links. Settings -> Support & About -> Beta Experiments includes the temporary unlimited-task override only in development apps; production ignores persisted and configured testing overrides.
- Calendar task import always supports Apple Calendar. Outlook appears only when the app bundle has a nonempty Microsoft Graph client ID, so unconfigured release builds do not advertise a nonfunctional sign-in path.
- The iOS and macOS production bundles declare `ITSAppUsesNonExemptEncryption` as false so App Store Connect can reuse Routina's current exempt-encryption answer. The declaration must be reassessed before shipping custom cryptography, encrypted communications or VPN functionality, or a cryptography-providing dependency.
- Beta Experiments are available only in development app variants. Production does not render the Beta Experiments panel after the hidden diagnostics gesture, resolves every experimental preference to disabled, and forces attempted experimental writes off, including values restored from older releases.
- The Mac production entitlement set omits location, audio input, and Apple Events automation because their Places, voice-note, and browser-automation entry points are experimental. The iOS production build likewise omits its location purpose string and compiles a no-op location client. Development builds retain those capabilities. Apple Calendar access remains a production feature and retains its calendar entitlement and purpose strings.
- Temporary, diagnostic, cache, migration, permission, and per-device handoff values can remain in `UserDefaults`.
- Hidden Support & About diagnostics show configured Data Mode and iCloud Container separately from the running executable's signed CloudKit environment. macOS reads the signed value from `com.apple.developer.icloud-container-environment`; iOS explicitly reports that this verification is unavailable rather than inferring it from configuration.
- Support & About shows the installed public Version and Build Number separately. Hidden diagnostics also shows the app's operating system and offers `Copy Diagnostics`. It copies a labelled report containing version, build number, operating-system, CloudKit, and push metadata only; it excludes user data, identifiers, credentials, and device tokens. A partial CloudKit failure includes up to three nested error codes and anonymized item fingerprints, never record names or contents.
- iCloud sync, reset, backup import, and backup export live in one iCloud & Backup settings section. `Sync Now` verifies the manual iCloud download only; local uploads remain asynchronous and must not be reported as completed until CloudKit records a successful export.
- iOS and macOS production archives compare the current persisted SwiftData model contract with `Config/CloudKit/production-schema.manifest`. A mismatch blocks the archive before TestFlight upload. After deploying the Development schema in CloudKit Dashboard, the release owner explicitly acknowledges it with `script/cloudkit_schema_guard.sh --acknowledge-production-deployment --yes-i-deployed-to-production` and commits the manifest.
- Estimated iCloud Usage lists only categories whose user-facing feature is available. Tasks, logs, and images remain visible; Places, Goals, Events, Emotions, Notes, and Voice Notes follow their corresponding feature gates.
- When `Show Goals tab` is off, iOS hides Goals navigation, New Goal, Goals Stats reports, the Goals iCloud category, and the Home Filters Goal option; existing task and goal data remains stored.
- iOS Settings -> Appearance hides the Task Row `Goals` and `Places` controls, their preview content, and their shown-fields count from the respective disabled Goal and Places feature gates. Their stored row-visibility choices remain intact and return when the feature is enabled again.
- iOS Settings -> Tags does not expose saved-tag quick-filter configuration until the app provides a discoverable shortcut surface. The deferred implementation is tracked in [Product Debt 0002](../debt/0002-implement-saved-tag-quick-filters.md).
- Default `.routinabackup` export/import and destructive reset are complete user-data operations over the SwiftData user model set.
- Legacy `.json` backup remains compatibility-only for older task, place, goal, and log payloads.
- Data-wide reset actions show backup/export first when possible.
- Destructive data reset requires a successful local backup export from the last 24 hours and fresh App Lock authentication.
- Settings reset requires App Lock to already be enabled and a fresh successful device-owner authentication. User content remains untouched.
- Turning App Lock off requires fresh device-owner authentication.
- Production hides Devices, Places, Notes, Away, task sharing, the linked-task visualizer, Goals, Adventure, Board, advanced Query sections, Wins, Achievements, Sleep scope, and the other Beta Experiment surfaces. Previously stored experimental content remains in persistence, sync, and backups.
- Development builds expose the experiment controls in Support & About after revealing diagnostics. Their toggles continue to drive the implemented experimental surfaces for internal testing.
- iOS app and website blocking remains available in development builds, but production omits its Settings entry, Screen Time implementation, and Family Controls entitlement until Apple approves the Family Controls distribution capability. macOS blocking remains unchanged.
- While Away is unavailable, Blocking exposes only Focus mode controls and Stats hides Sleep-specific surfaces.
- Mac app widget source remains in the repository, but the Mac app targets do not build, embed, or register widget extensions, so Routina widgets are not exposed on macOS.
- macOS development runs use `script/build_and_run.sh` by default. Production launches use the explicit `--prod` path.
- The embedded macOS MCP helper inherits Routina's App Sandbox and is signed with only the App Sandbox and inheritance entitlements required for a Mac App Store helper executable.
- The Mac development app exposes screenshot preparation in Settings -> Appearance. Its development badge remains visible by default but can be hidden with `Show development badge`; `Generate Screenshot Data` adds an idempotent, non-destructive set of representative tasks, history, planner blocks, focus, goals, notes, events, emotions, sleep, and Away records. Production hides these controls and ignores the screenshot seed launch trigger.
