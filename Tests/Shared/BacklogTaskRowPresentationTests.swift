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
struct BacklogTaskRowPresentationTests {
    @Test
    func sparseBacklogDefaultAndAvailableFieldsRemainIndependent() {
        let visibility = HomeTaskRowVisibility.backlogDefaultValue

        #expect(visibility.allowsMultilineTitles)
        #expect(visibility.shows(.icon))
        #expect(!visibility.shows(.rowColor))
        #expect(!visibility.shows(.statusBadge))
        #expect(!visibility.shows(.tags))
        #expect(
            HomeTaskRowVisibility(
                storageRawValue: HomeTaskRowVisibility.backlogDefaultStorageRawValue
            ) == visibility
        )

        let fieldsWithoutPlaces = HomeTaskRowField.backlogAppearanceFields(showsPlaces: false)
        #expect(fieldsWithoutPlaces.contains(.taskTypeBadge))
        #expect(fieldsWithoutPlaces.contains(.flags))
        #expect(!fieldsWithoutPlaces.contains(.goals))
        #expect(!fieldsWithoutPlaces.contains(.place))

        let fieldsWithPlaces = HomeTaskRowField.backlogAppearanceFields(showsPlaces: true)
        #expect(fieldsWithPlaces.contains(.place))
    }

    @Test
    func cachedRowContainsAppearanceMetadataAndVisibleNumber() throws {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1_735_905_600)
        let sectionID = UUID()
        let task = RoutineTask(
            name: "Draft proposal",
            emoji: "📝",
            deadline: referenceDate,
            customTaskSectionID: sectionID,
            pressure: .high,
            imageData: Data([0x01]),
            destinationAddress: "Library",
            tags: ["Work"],
            flags: ["Off radar"],
            steps: [
                RoutineStep(title: "Outline"),
                RoutineStep(title: "Review"),
            ],
            scheduleMode: .oneOff,
            pinnedAt: referenceDate,
            color: .purple,
            todoStateRawValue: TodoState.inProgress.rawValue
        )
        let section = HomeCustomTaskSection(
            id: sectionID,
            surface: .backlog,
            title: "Someday",
            createdAt: nil
        )

        let presentation = BacklogTaskListPresentation.make(
            tasks: [task],
            customSections: [section],
            flagRules: [RoutineFlagRule(flag: "Off radar", kind: .hideFromTaskLists)],
            referenceDate: referenceDate,
            calendar: calendar
        )

        let row = try #require(presentation.rowPresentationsByTaskID[task.id])
        #expect(row.name == "Draft proposal")
        #expect(row.emoji == "📝")
        #expect(row.hasImage)
        #expect(row.isPinned)
        #expect(row.isOneOffTask)
        #expect(row.color == .purple)
        #expect(row.status?.title == "In Progress")
        #expect(row.tags == ["Work"])
        #expect(row.flags == ["Off radar"])
        #expect(row.hidingFlags == ["Off radar"])
        #expect(
            row.metadataText(for: .defaultValue, showsPlaces: true)
                == "Due today • High pressure • Step 1 of 2 • Next: Outline • Library"
        )
        #expect(presentation.rowNumbersByTaskID[task.id] == 1)
    }

    @Test
    func backupAndRestorePreserveWorkspaceAppearancePreferences() throws {
        let defaults = SharedDefaults.app
        let key = UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields
        let taskLadderKey = UserDefaultStringValueKey.appSettingTaskLadderTaskRowHiddenFields
        let previousValue = defaults.object(forKey: key.rawValue)
        let previousTaskLadderValue = defaults.object(forKey: taskLadderKey.rawValue)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key.rawValue)
            } else {
                defaults.removeObject(forKey: key.rawValue)
            }
            if let previousTaskLadderValue {
                defaults.set(previousTaskLadderValue, forKey: taskLadderKey.rawValue)
            } else {
                defaults.removeObject(forKey: taskLadderKey.rawValue)
            }
        }
        defaults[key] = "rowColor,rowNumber"
        defaults[taskLadderKey] = "statusBadge,flags"

        let sourceContext = makeInMemoryContext()
        let package = try SettingsRoutineDataPersistence.buildBackupPackage(from: sourceContext)
        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(from: package.manifestData)
        #expect(backup.userPreferences?.backlogTaskRowHiddenFields == "rowColor,rowNumber")
        #expect(backup.userPreferences?.taskLadderTaskRowHiddenFields == "statusBadge,flags")

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext
        )
        let restored = try #require(
            restoreContext.fetch(FetchDescriptor<RoutinaUserPreferences>()).first
        )
        #expect(summary.userPreferences == 1)
        #expect(restored.backlogTaskRowHiddenFields == "rowColor,rowNumber")
        #expect(restored.taskLadderTaskRowHiddenFields == "statusBadge,flags")
    }
}
