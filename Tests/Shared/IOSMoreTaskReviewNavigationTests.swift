import Foundation
import Testing

struct IOSMoreTaskReviewNavigationTests {
    @Test
    func taskReviewActionsAreGroupedBehindOneMoreDestination() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let moreList = try Self.sourceSection(
            startingAt: "private var moreList",
            endingAt: "private var taskReviewList",
            in: source
        )
        let taskReviewList = try Self.sourceSection(
            startingAt: "private var taskReviewList",
            endingAt: "private var settingsSubtitle",
            in: source
        )

        #expect(source.contains("case taskReview"))
        #expect(moreList.contains("moreButton(destination: .taskReview)"))
        #expect(moreList.contains("title: \"Review tasks\""))
        #expect(!moreList.contains("destination: .taskChoice"))
        #expect(!moreList.contains("destination: .missingPressureData"))
        #expect(!moreList.contains("destination: .missingThinkingNeededData"))
        #expect(!moreList.contains("destination: .missingEstimatedDurationData"))
        #expect(!moreList.contains("destination: .missingImportanceData"))
        #expect(!moreList.contains("destination: .missingUrgencyData"))

        #expect(taskReviewList.contains("NavigationLink"))
        #expect(taskReviewList.contains("TaskChoiceView(store: taskChoiceStore)"))
        #expect(taskReviewList.contains("Section(\"Add missing task details\")"))
        #expect(taskReviewList.contains("MissingTaskDataView(store: missingPressureDataStore)"))
        #expect(taskReviewList.contains("MissingTaskDataView(store: missingThinkingNeededDataStore)"))
        #expect(taskReviewList.contains("MissingTaskDataView(store: missingEstimatedDurationDataStore)"))
        #expect(taskReviewList.contains("MissingTaskMetadataView(store: missingImportanceDataStore)"))
        #expect(taskReviewList.contains("MissingTaskMetadataView(store: missingUrgencyDataStore)"))
    }

    private static func sourceSection(
        startingAt startMarker: String,
        endingAt endMarker: String,
        in source: String
    ) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(
            source.range(
                of: endMarker,
                range: start.upperBound..<source.endIndex
            )
        )
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
