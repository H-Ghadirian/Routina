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
struct TaskRankingRowPresentationTests {
    @Test
    func taskLadderDefaultPreservesItsExistingSparseRowContext() {
        let visibility = HomeTaskRowVisibility.taskLadderDefaultValue

        #expect(visibility.allowsMultilineTitles)
        #expect(visibility.shows(.icon))
        #expect(visibility.shows(.taskTypeBadge))
        #expect(visibility.shows(.tags))
        #expect(!visibility.shows(.rowColor))
        #expect(!visibility.shows(.statusBadge))
        #expect(
            HomeTaskRowVisibility(
                storageRawValue: HomeTaskRowVisibility.taskLadderDefaultStorageRawValue
            ) == visibility
        )

        let fields = HomeTaskRowField.taskLadderAppearanceFields(showsPlaces: false)
        #expect(fields.contains(.taskTypeBadge))
        #expect(fields.contains(.flags))
        #expect(!fields.contains(.goals))
        #expect(!fields.contains(.place))
        #expect(HomeTaskRowField.taskLadderAppearanceFields(showsPlaces: true).contains(.place))
    }

    @Test
    func taskLadderSnapshotCachesAppearanceMetadataAndRowNumbers() throws {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1_735_905_600)
        let task = RoutineTask(
            name: "Draft proposal",
            emoji: "📝",
            deadline: referenceDate,
            pressure: .high,
            imageData: Data([0x01]),
            destinationAddress: "Library",
            tags: ["Work"],
            flags: ["Review"],
            steps: [RoutineStep(title: "Outline")],
            scheduleMode: .oneOff,
            color: .purple,
            todoStateRawValue: TodoState.inProgress.rawValue
        )

        let presentation = TaskRankingPresentation.make(
            tasks: [task],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let metadata = try #require(presentation.rowMetadataByTaskID[task.id])
        #expect(metadata.appearance.name == "Draft proposal")
        #expect(metadata.appearance.emoji == "📝")
        #expect(metadata.appearance.hasImage)
        #expect(metadata.appearance.taskType == .todo)
        #expect(metadata.appearance.color == .purple)
        #expect(metadata.appearance.status?.title == "In Progress")
        #expect(metadata.appearance.tags == ["Work"])
        #expect(metadata.appearance.flags == ["Review"])
        #expect(
            metadata.appearance.metadataText(for: .defaultValue, showsPlaces: true)
                == "Due today • High pressure • Step 1 of 1 • Next: Outline • Library"
        )
        #expect(presentation.rowNumbersByTaskID[task.id] == 1)
    }

    @Test
    func backlogAndTaskLadderUseTheSameTaskSemanticPresentation() {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1_735_905_600)
        let task = RoutineTask(
            name: "  Review roadmap  ",
            emoji: "🧭",
            deadline: referenceDate,
            imageData: Data([0x01]),
            destinationAddress: "Library",
            tags: ["Work"],
            flags: ["Off radar"],
            steps: [RoutineStep(title: "Outline")],
            scheduleMode: .oneOff,
            pinnedAt: referenceDate,
            color: .purple,
            todoStateRawValue: TodoState.inProgress.rawValue
        )
        let flagRules = [RoutineFlagRule(flag: "Off radar", kind: .hideFromTaskLists)]

        let backlog = BacklogTaskRowPresentation.make(
            task: task,
            flagRules: flagRules,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let ladder = TaskRankingRowPresentation.make(
            task: task,
            isContainerGroup: false,
            flagRules: flagRules,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let home = HomeRoutineDisplayFactory(now: referenceDate, calendar: calendar).makeCore(
            for: task,
            placesByID: [:],
            goalsByID: [:],
            locationSnapshot: LocationSnapshot(
                authorizationStatus: .notDetermined,
                coordinate: nil,
                horizontalAccuracy: nil,
                timestamp: nil
            ),
            doneStats: HomeDoneStats(),
            flagRules: flagRules
        )

        #expect(backlog == ladder)
        #expect(home.taskRowSemantics == backlog)
        #expect(home.name == backlog.name)
        #expect(home.emoji == backlog.emoji)
        #expect(home.hasImage == backlog.hasImage)
        #expect(home.isPinned == backlog.isPinned)
        #expect(home.tags == backlog.tags)
        #expect(home.flags == backlog.flags)
        #expect(home.color == backlog.color)
        #expect(backlog.status?.title == "In Progress")
        #expect(backlog.scheduleText == "Due today")
    }

    @Test
    func taskLadderSearchCachesTheSameSemanticRowForIOS() throws {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1_735_905_600)
        let task = RoutineTask(
            name: "Review roadmap",
            emoji: "🧭",
            deadline: referenceDate,
            scheduleMode: .oneOff
        )
        let ranked = TaskRankingPresentation.make(
            tasks: [task],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let search = TaskRankingSearchPresentation.make(
            tasks: [task],
            organization: TaskLadderOrganization(),
            eligibleTaskIDs: ranked.eligibleTaskIDs,
            flagRules: [],
            metric: .pressure,
            valueMode: .base,
            searchText: "roadmap",
            referenceDate: referenceDate,
            calendar: calendar
        )

        let match = try #require(search.matches.first)
        let rankedRow = try #require(ranked.rowMetadataByTaskID[task.id])
        #expect(match.appearance == rankedRow.appearance)
        #expect(match.appearance.status?.title == "To Do")
    }
}
