import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct SettingsRoutineDataPersistenceTests {
    @Test
    func writeBackup_toJSONURLWritesLegacyJSONFile() async throws {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Archive paperwork", tags: ["Admin"])
        context.insert(task)
        try context.save()

        let jsonURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.legacyJSONBackupExtension)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        try SettingsRoutineDataPersistence.writeBackup(to: jsonURL, from: context)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: jsonURL.path, isDirectory: &isDirectory))
        #expect(!isDirectory.boolValue)

        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(
            from: Data(contentsOf: jsonURL)
        )
        #expect(backup.schemaVersion == SettingsRoutineDataPersistence.legacyJSONSchemaVersion)
        #expect(backup.tasks.map(\.id) == [task.id])
        #expect(backup.tasks.first?.tags == ["Admin"])
    }

    @Test
    func backupPackageAndRestore_preservesGoalHierarchy() async throws {
        let context = makeInMemoryContext()
        let parent = RoutineGoal(title: "Health")
        let rejectedTaskID = UUID()
        let child = RoutineGoal(
            title: "Run 5K",
            tags: ["Health", "Race"],
            parentGoalID: parent.id,
            rejectedTaskSuggestionIDs: [rejectedTaskID]
        )
        context.insert(parent)
        context.insert(child)
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        let restoredGoals = try restoreContext.fetch(FetchDescriptor<RoutineGoal>())
        let restoredParent = try #require(restoredGoals.first { $0.id == parent.id })
        let restoredChild = try #require(restoredGoals.first { $0.id == child.id })

        #expect(summary.goals == 2)
        #expect(restoredParent.parentGoalID == nil)
        #expect(restoredChild.parentGoalID == parent.id)
        #expect(restoredChild.tags == ["Health", "Race"])
        #expect(restoredChild.rejectedTaskSuggestionIDs == [rejectedTaskID])
    }

    @Test
    func backupPackageAndRestore_preservesUserPreferences() async throws {
        let context = makeInMemoryContext()
        let defaults = SharedDefaults.app
        let keysToRestore = [
            UserDefaultStringValueKey.selectedMacAppIcon.rawValue,
            UserDefaultStringValueKey.appSettingAppColorScheme.rawValue,
            UserDefaultStringValueKey.appSettingRelatedTagRules.rawValue,
            UserDefaultStringValueKey.appSettingTagColors.rawValue,
            UserDefaultStringValueKey.appSettingFastFilterTags.rawValue,
            UserDefaultStringValueKey.appSettingIOSStatsDashboardHiddenItemIDs.rawValue,
            UserDefaultStringValueKey.appSettingMacStatsDashboardItemOrderIDs.rawValue,
            UserDefaultStringValueKey.appSettingProtectionBlockingEnabledModes.rawValue,
            UserDefaultStringValueKey.appSettingBlockingWebsiteDomains.rawValue,
            UserDefaultStringValueKey.appSettingMacFocusBlockedApps.rawValue,
            UserDefaultStringValueKey.macFormSectionOrder.rawValue,
            UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
            UserDefaultStringValueKey.appSettingMacAdventureOwnedItemIDs.rawValue,
            UserDefaultBoolValueKey.appSettingNotificationsEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingAppLockEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingTaskSharingEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingTaskRelationshipVisualizerEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingUnlockUnlimitedTasks.rawValue,
            UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
            UserDefaultBoolValueKey.appSettingFocusShieldEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingAutomaticPlaceCheckInEnabled.rawValue,
            UserDefaultBoolValueKey.appSettingSeparateDailyRoutinesInTaskList.rawValue,
            UserDefaultBoolValueKey.appSettingShowTomorrowInTaskList.rawValue,
            UserDefaultBoolValueKey.appSettingMacShowDoneCountInToolbar.rawValue,
            UserDefaultBoolValueKey.appSettingSeparateTodosAndRoutinesInTagTaskListSections.rawValue,
            UserDefaultBoolValueKey.appSettingSeparateDeadlineStatusInTagTaskListSections.rawValue,
            BatteryRoutinePreferences.thresholdPercentDefaultsKey
        ]
        let previousValues = Dictionary(uniqueKeysWithValues: keysToRestore.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for (key, value) in previousValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults[.selectedMacAppIcon] = AppIconOption.teal.rawValue
        defaults[.appSettingAppColorScheme] = AppColorScheme.dark.rawValue
        defaults[.appSettingRelatedTagRules] = "[{\"tag\":\"Focus\",\"relatedTags\":[\"Deep Work\"]}]"
        defaults[.appSettingTagColors] = "{\"Focus\":\"#112233\"}"
        defaults[.appSettingFastFilterTags] = "Focus,Health"
        defaults[.appSettingIOSStatsDashboardHiddenItemIDs] = "movement"
        defaults[.appSettingMacStatsDashboardItemOrderIDs] = "done,focus"
        defaults[.appSettingProtectionBlockingEnabledModes] = ProtectionBlockingMode.encodedSet([.focus])
        defaults[.appSettingBlockingWebsiteDomains] = "example.com"
        defaults[.appSettingMacFocusBlockedApps] = "com.example.Blocked"
        let formOrderData = try JSONEncoder().encode(["schedule", "tags"])
        defaults.set(formOrderData, forKey: UserDefaultStringValueKey.macFormSectionOrder.rawValue)
        defaults[.macQuickAddShortcut] = "optionCommandK"
        defaults[.appSettingMacAdventureOwnedItemIDs] = "map"
        defaults[.appSettingNotificationsEnabled] = true
        defaults[.appSettingAppLockEnabled] = true
        defaults[.appSettingTaskSharingEnabled] = true
        defaults[.appSettingTaskRelationshipVisualizerEnabled] = true
        defaults[.appSettingPlacesEnabled] = true
        defaults[.appSettingNotesEnabled] = true
        defaults[.appSettingAwayEnabled] = true
        defaults[.appSettingFilterQuerySectionsEnabled] = true
        defaults[.appSettingUnlockUnlimitedTasks] = true
        defaults[.appSettingShowPersianDates] = true
        defaults[.appSettingFocusShieldEnabled] = true
        defaults[.appSettingAutomaticPlaceCheckInEnabled] = false
        defaults[.appSettingSeparateDailyRoutinesInTaskList] = true
        defaults[.appSettingShowTomorrowInTaskList] = true
        defaults[.appSettingMacShowDoneCountInToolbar] = true
        defaults[.appSettingSeparateTodosAndRoutinesInTagTaskListSections] = true
        defaults[.appSettingSeparateDeadlineStatusInTagTaskListSections] = true
        defaults.set(35, forKey: BatteryRoutinePreferences.thresholdPercentDefaultsKey)

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(from: context)
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: package.manifestData)

        #expect(backup.userPreferences?.selectedAppIcon == AppIconOption.teal.rawValue)
        #expect(backup.userPreferences?.tagColors == "{\"Focus\":\"#112233\"}")
        #expect(backup.userPreferences?.taskSharingEnabled == true)
        #expect(backup.userPreferences?.taskRelationshipVisualizerEnabled == true)
        #expect(backup.userPreferences?.placesEnabled == true)
        #expect(backup.userPreferences?.notesEnabled == true)
        #expect(backup.userPreferences?.awayEnabled == true)
        #expect(backup.userPreferences?.filterQuerySectionsEnabled == true)
        #expect(backup.userPreferences?.unlockUnlimitedTasks == true)
        #expect(backup.userPreferences?.separateTodosAndRoutinesInTagTaskListSections == true)
        #expect(backup.userPreferences?.separateDeadlineStatusInTagTaskListSections == true)
        #expect(backup.userPreferences?.showTomorrowInTaskList == true)
        #expect(backup.userPreferences?.macShowDoneCountInToolbar == true)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext
        )

        let restored = try #require(restoreContext.fetch(FetchDescriptor<RoutinaUserPreferences>()).first)
        #expect(summary.userPreferences == 1)
        #expect(restored.selectedAppIcon == AppIconOption.teal.rawValue)
        #expect(restored.appColorScheme == AppColorScheme.dark.rawValue)
        #expect(restored.relatedTagRules == "[{\"tag\":\"Focus\",\"relatedTags\":[\"Deep Work\"]}]")
        #expect(restored.tagColors == "{\"Focus\":\"#112233\"}")
        #expect(restored.fastFilterTags == "Focus,Health")
        #expect(restored.iOSStatsDashboardHiddenItemIDs == "movement")
        #expect(restored.macStatsDashboardItemOrderIDs == "done,focus")
        #expect(restored.protectionBlockingEnabledModes == ProtectionBlockingMode.encodedSet([.focus]))
        #expect(restored.blockingWebsiteDomains == "example.com")
        #expect(restored.macFocusBlockedApps == "com.example.Blocked")
        #expect(restored.macFormSectionOrder == formOrderData.base64EncodedString())
        #expect(restored.macQuickAddShortcut == "optionCommandK")
        #expect(restored.macAdventureOwnedItemIDs == "map")
        #expect(restored.notificationsEnabled)
        #expect(restored.appLockEnabled)
        #expect(restored.taskSharingEnabled)
        #expect(restored.taskRelationshipVisualizerEnabled)
        #expect(restored.placesEnabled)
        #expect(restored.notesEnabled)
        #expect(restored.awayEnabled)
        #expect(restored.filterQuerySectionsEnabled)
        #expect(restored.unlockUnlimitedTasks)
        #expect(restored.showPersianDates)
        #expect(restored.focusShieldEnabled)
        #expect(!restored.automaticPlaceCheckInEnabled)
        #expect(restored.separateDailyRoutinesInTaskList)
        #expect(restored.showTomorrowInTaskList)
        #expect(restored.macShowDoneCountInToolbar)
        #expect(restored.separateTodosAndRoutinesInTagTaskListSections)
        #expect(restored.separateDeadlineStatusInTagTaskListSections)
        #expect(restored.batteryRoutineThresholdPercent == 35)
    }

    @Test
    func localUserDataReset_deletesUserPreferences() async throws {
        let context = makeInMemoryContext()
        let preferences = try RoutinaUserPreferencesStore.fetchOrCreate(in: context)
        preferences.tagColors = "{\"Focus\":\"#112233\"}"
        try context.save()

        try LocalUserDataResetService.wipeAllUserData(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutinaUserPreferences>())
        #expect(remaining.isEmpty)
    }

    @Test
    func backupPackageAndRestore_preservesTaskImagesVoiceNotesAndAttachments() async throws {
        let context = makeInMemoryContext()
        let imageData = Data([0x01, 0x02, 0x03])
        let voiceData = Data([0x07, 0x08, 0x09])
        let voiceCreatedAt = Date(timeIntervalSince1970: 250)
        let attachmentData = Data([0x04, 0x05, 0x06])
        let task = RoutineTask(
            name: "File insurance",
            pressure: .high,
            imageData: imageData,
            voiceNoteData: voiceData,
            voiceNoteDurationSeconds: 3.5,
            voiceNoteCreatedAt: voiceCreatedAt
        )
        context.insert(task)
        context.insert(
            RoutineAttachment(
                taskID: task.id,
                fileName: "receipt.jpg",
                data: attachmentData
            )
        )
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        #expect(summary.tasks == 1)
        #expect(summary.attachments == 1)
        let restoredTask = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restoredTask.imageData == imageData)
        #expect(restoredTask.voiceNoteData == voiceData)
        #expect(restoredTask.voiceNoteDurationSeconds == 3.5)
        #expect(restoredTask.voiceNoteCreatedAt == voiceCreatedAt)
        #expect(restoredTask.pressure == .high)
        let restoredAttachment = try #require(restoreContext.fetch(FetchDescriptor<RoutineAttachment>()).first)
        #expect(restoredAttachment.taskID == restoredTask.id)
        #expect(restoredAttachment.fileName == "receipt.jpg")
        #expect(restoredAttachment.data == attachmentData)
    }

    @Test
    func backupPackageAndRestore_preservesStandaloneNotesAndAttachments() async throws {
        let context = makeInMemoryContext()
        let imageData = Data([0x11, 0x12])
        let voiceData = Data([0x21, 0x22])
        let fileData = Data([0x31, 0x32])
        let createdAt = Date(timeIntervalSince1970: 300)
        let updatedAt = Date(timeIntervalSince1970: 360)
        let voiceCreatedAt = Date(timeIntervalSince1970: 330)
        let note = RoutineNote(
            title: "Visa paperwork",
            body: "Attach scanned permit forms",
            tags: ["Admin", "Visa"],
            imageData: imageData,
            voiceNoteData: voiceData,
            voiceNoteDurationSeconds: 4.25,
            voiceNoteCreatedAt: voiceCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(note)
        context.insert(
            RoutineNoteAttachment(
                noteID: note.id,
                fileName: "permit.pdf",
                data: fileData,
                createdAt: createdAt
            )
        )
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        #expect(summary.notes == 1)
        #expect(summary.attachments == 1)
        let restoredNote = try #require(restoreContext.fetch(FetchDescriptor<RoutineNote>()).first)
        #expect(restoredNote.title == "Visa paperwork")
        #expect(restoredNote.body == "Attach scanned permit forms")
        #expect(restoredNote.tags == ["Admin", "Visa"])
        #expect(restoredNote.imageData == imageData)
        #expect(restoredNote.voiceNoteData == voiceData)
        #expect(restoredNote.voiceNoteDurationSeconds == 4.25)
        #expect(restoredNote.voiceNoteCreatedAt == voiceCreatedAt)
        #expect(restoredNote.createdAt == createdAt)
        #expect(restoredNote.updatedAt == updatedAt)
        let restoredAttachment = try #require(restoreContext.fetch(FetchDescriptor<RoutineNoteAttachment>()).first)
        #expect(restoredAttachment.noteID == restoredNote.id)
        #expect(restoredAttachment.fileName == "permit.pdf")
        #expect(restoredAttachment.data == fileData)
    }

    @Test
    func backupPackageAndRestore_preservesStandaloneEvents() async throws {
        let context = makeInMemoryContext()
        let startedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endedAt = Date(timeIntervalSince1970: 1_780_086_400)
        let reminderAt = Date(timeIntervalSince1970: 1_779_996_000)
        let createdAt = Date(timeIntervalSince1970: 1_779_990_000)
        let updatedAt = Date(timeIntervalSince1970: 1_779_995_000)
        let event = RoutineEvent(
            title: "Sick day",
            notes: "Fever and rest",
            emoji: "🤒",
            tags: ["Health", "Recovery"],
            isAllDay: true,
            startedAt: startedAt,
            endedAt: endedAt,
            reminderAt: reminderAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(event)
        let task = RoutineTask(
            name: "Follow up",
            eventIDs: [event.id]
        )
        context.insert(task)
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        #expect(summary.events == 1)
        #expect(summary.tasks == 1)
        let restoredEvent = try #require(restoreContext.fetch(FetchDescriptor<RoutineEvent>()).first)
        let restoredTask = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restoredEvent.id == event.id)
        #expect(restoredEvent.title == "Sick day")
        #expect(restoredEvent.notes == "Fever and rest")
        #expect(restoredEvent.emoji == "🤒")
        #expect(restoredEvent.tags == ["Health", "Recovery"])
        #expect(restoredEvent.isAllDay)
        #expect(restoredEvent.startedAt == startedAt)
        #expect(restoredEvent.endedAt == endedAt)
        #expect(restoredEvent.reminderAt == reminderAt)
        #expect(restoredEvent.createdAt == createdAt)
        #expect(restoredEvent.updatedAt == updatedAt)
        #expect(restoredTask.eventIDs == [event.id])
    }

    @Test
    func backupPackageAndRestore_preservesPlannerBoardFocusAndDeviceData() async throws {
        let context = makeInMemoryContext()
        let createdAt = Date(timeIntervalSince1970: 1_780_100_000)
        let updatedAt = Date(timeIntervalSince1970: 1_780_101_000)
        let task = RoutineTask(
            name: "Stretch",
            emoji: "🧘",
            scheduleMode: .oneOff,
            createdAt: createdAt
        )
        context.insert(task)

        let focus = FocusSession(
            taskID: task.id,
            startedAt: createdAt,
            plannedDurationSeconds: 30 * 60,
            completedAt: updatedAt,
            accumulatedPausedSeconds: 60
        )
        let plannerBlock = DayPlanBlockRecord(
            taskID: task.id,
            dayKey: "2026-06-06",
            startMinute: 9 * 60,
            durationMinutes: 45,
            titleSnapshot: "Stretch",
            emojiSnapshot: "🧘",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let sprint = BoardSprintRecord(
            title: "Launch",
            status: .active,
            createdAt: createdAt,
            startedAt: createdAt
        )
        let backlog = BoardBacklogRecord(
            title: "Later",
            createdAt: createdAt,
            routingTags: ["Someday"]
        )
        let sprintAssignment = SprintAssignmentRecord(
            todoID: task.id,
            sprintID: sprint.id,
            sortOrder: 3
        )
        let backlogAssignment = BacklogAssignmentRecord(
            todoID: task.id,
            backlogID: backlog.id,
            sortOrder: 4
        )
        let sprintFocus = SprintFocusSessionRecord(
            sprintID: sprint.id,
            startedAt: createdAt,
            stoppedAt: updatedAt,
            accumulatedPausedSeconds: 30
        )
        let sprintAllocation = SprintFocusAllocationRecord(
            sessionID: sprintFocus.id,
            taskID: task.id,
            minutes: 25,
            sortOrder: 2
        )
        let source = RoutinaDeviceActivitySource(
            installationID: "install-1",
            displayName: "Mac Studio",
            platform: .mac,
            modelName: "Mac",
            systemName: "macOS",
            systemVersion: "26.4",
            appVersion: "1.0",
            bundleIdentifier: "com.routina.test"
        )
        let deviceSession = RoutinaDeviceSession(
            installationID: source.installationID,
            displayName: source.displayName,
            platform: source.platform,
            modelName: source.modelName,
            systemName: source.systemName,
            systemVersion: source.systemVersion,
            appVersion: source.appVersion,
            bundleIdentifier: source.bundleIdentifier,
            firstSeenAt: createdAt,
            lastSeenAt: updatedAt,
            lastActiveAt: updatedAt,
            lastMutationAt: updatedAt
        )
        let deviceLog = RoutinaDeviceActionLog(
            timestamp: updatedAt,
            action: .completed,
            entity: .focusSession,
            entityID: focus.id.uuidString,
            entityTitle: "Stretch",
            source: source,
            details: "Completed focus"
        )

        context.insert(focus)
        context.insert(plannerBlock)
        context.insert(sprint)
        context.insert(backlog)
        context.insert(sprintAssignment)
        context.insert(backlogAssignment)
        context.insert(sprintFocus)
        context.insert(sprintAllocation)
        context.insert(deviceSession)
        context.insert(deviceLog)
        try context.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(
            from: context,
            exportedAt: updatedAt
        )
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: package.manifestData)

        #expect(backup.schemaVersion == SettingsRoutineDataPersistence.currentSchemaVersion)
        #expect(backup.focusSessions?.count == 1)
        #expect(backup.dayPlanBlocks?.count == 1)
        #expect(backup.boardSprints?.count == 1)
        #expect(backup.sprintAssignments?.count == 1)
        #expect(backup.boardBacklogs?.count == 1)
        #expect(backup.backlogAssignments?.count == 1)
        #expect(backup.sprintFocusSessions?.count == 1)
        #expect(backup.sprintFocusAllocations?.count == 1)
        #expect(backup.deviceSessions?.count == 1)
        #expect(backup.deviceActionLogs?.count == 1)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext,
            importDate: updatedAt
        )

        #expect(summary.tasks == 1)
        #expect(summary.focusSessions == 1)
        #expect(summary.dayPlanBlocks == 1)
        #expect(summary.boardSprints == 1)
        #expect(summary.sprintAssignments == 1)
        #expect(summary.boardBacklogs == 1)
        #expect(summary.backlogAssignments == 1)
        #expect(summary.sprintFocusSessions == 1)
        #expect(summary.sprintFocusAllocations == 1)
        #expect(summary.deviceSessions == 1)
        #expect(summary.deviceActionLogs == 1)

        let restoredFocus = try #require(restoreContext.fetch(FetchDescriptor<FocusSession>()).first)
        let restoredBlock = try #require(restoreContext.fetch(FetchDescriptor<DayPlanBlockRecord>()).first)
        let restoredSprint = try #require(restoreContext.fetch(FetchDescriptor<BoardSprintRecord>()).first)
        let restoredBacklog = try #require(restoreContext.fetch(FetchDescriptor<BoardBacklogRecord>()).first)
        let restoredSprintAssignment = try #require(restoreContext.fetch(FetchDescriptor<SprintAssignmentRecord>()).first)
        let restoredBacklogAssignment = try #require(restoreContext.fetch(FetchDescriptor<BacklogAssignmentRecord>()).first)
        let restoredSprintFocus = try #require(restoreContext.fetch(FetchDescriptor<SprintFocusSessionRecord>()).first)
        let restoredAllocation = try #require(restoreContext.fetch(FetchDescriptor<SprintFocusAllocationRecord>()).first)
        let restoredDevice = try #require(restoreContext.fetch(FetchDescriptor<RoutinaDeviceSession>()).first)
        let restoredDeviceLog = try #require(restoreContext.fetch(FetchDescriptor<RoutinaDeviceActionLog>()).first)

        #expect(restoredFocus.id == focus.id)
        #expect(restoredFocus.taskID == task.id)
        #expect(restoredFocus.completedAt == updatedAt)
        #expect(restoredFocus.accumulatedPausedSeconds == 60)
        #expect(restoredBlock.id == plannerBlock.id)
        #expect(restoredBlock.dayKey == "2026-06-06")
        #expect(restoredBlock.titleSnapshot == "Stretch")
        #expect(restoredSprint.id == sprint.id)
        #expect(restoredSprint.statusRawValue == SprintStatus.active.rawValue)
        #expect(restoredBacklog.routingTags == ["Someday"])
        #expect(restoredSprintAssignment.sortOrder == 3)
        #expect(restoredBacklogAssignment.sortOrder == 4)
        #expect(restoredSprintFocus.id == sprintFocus.id)
        #expect(restoredSprintFocus.stoppedAt == updatedAt)
        #expect(restoredAllocation.sessionID == sprintFocus.id)
        #expect(restoredAllocation.minutes == 25)
        #expect(restoredAllocation.sortOrder == 2)
        #expect(restoredDevice.installationID == source.installationID)
        #expect(restoredDevice.lastMutationAt == updatedAt)
        #expect(restoredDeviceLog.action == .completed)
        #expect(restoredDeviceLog.entity == .focusSession)
        #expect(restoredDeviceLog.entityID == focus.id.uuidString)
        #expect(restoredDeviceLog.details == "Completed focus")
    }

    @Test
    func backupPackageAndRestore_preservesTagFocusSessions() async throws {
        let context = makeInMemoryContext()
        let exportedAt = Date(timeIntervalSince1970: 3_000)
        let focus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSince1970: 2_900),
            plannedDurationSeconds: 25 * 60,
            completedAt: Date(timeIntervalSince1970: 3_000),
            tagName: "Admin"
        )
        context.insert(focus)
        try context.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(
            from: context,
            exportedAt: exportedAt
        )
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: package.manifestData)

        #expect(backup.focusSessions?.first?.tagName == "Admin")

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext,
            importDate: exportedAt
        )

        let restoredFocus = try #require(restoreContext.fetch(FetchDescriptor<FocusSession>()).first)
        #expect(summary.focusSessions == 1)
        #expect(restoredFocus.id == focus.id)
        #expect(restoredFocus.isTagFocus)
        #expect(restoredFocus.focusTagName == "Admin")
        #expect(restoredFocus.taskID == FocusSession.unassignedTaskID)
    }

    @Test
    func backupPackageAndRestore_preservesEmotionLogsAndLinks() async throws {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Appointment")
        let goal = RoutineGoal(title: "Health")
        let place = RoutinePlace(name: "Clinic", latitude: 52.52, longitude: 13.405)
        let sleep = SleepSession(
            startedAt: Date(timeIntervalSince1970: 500),
            endedAt: Date(timeIntervalSince1970: 800)
        )
        let note = RoutineNote(title: "Doctor questions")
        context.insert(task)
        context.insert(goal)
        context.insert(place)
        context.insert(sleep)
        context.insert(note)

        let emotion = EmotionLog(
            families: [.fear, .anger],
            labels: ["worried", "frustrated"],
            valence: -0.65,
            arousal: 0.72,
            intensity: 4,
            bodyAreas: [.chest, .stomach],
            reflection: "Waiting for results",
            linkedNoteID: note.id,
            linkedGoalID: goal.id,
            linkedTaskID: task.id,
            linkedPlaceID: place.id,
            linkedSleepSessionID: sleep.id,
            createdAt: Date(timeIntervalSince1970: 900),
            updatedAt: Date(timeIntervalSince1970: 960)
        )
        context.insert(emotion)
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        #expect(summary.emotionLogs == 1)
        let restoredEmotion = try #require(restoreContext.fetch(FetchDescriptor<EmotionLog>()).first)
        #expect(restoredEmotion.families == [.fear, .anger])
        #expect(restoredEmotion.labels == ["worried", "frustrated"])
        #expect(restoredEmotion.family == .fear)
        #expect(restoredEmotion.label == "worried")
        #expect(restoredEmotion.displayLabel == "worried, frustrated")
        #expect(restoredEmotion.valence == -0.65)
        #expect(restoredEmotion.arousal == 0.72)
        #expect(restoredEmotion.intensity == 4)
        #expect(restoredEmotion.bodyAreas == [.chest, .stomach])
        #expect(restoredEmotion.reflection == "Waiting for results")
        #expect(restoredEmotion.linkedNoteID == note.id)
        #expect(restoredEmotion.linkedGoalID == goal.id)
        #expect(restoredEmotion.linkedTaskID == task.id)
        #expect(restoredEmotion.linkedPlaceID == place.id)
        #expect(restoredEmotion.linkedSleepSessionID == sleep.id)
    }
}
