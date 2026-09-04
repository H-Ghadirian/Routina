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
}
