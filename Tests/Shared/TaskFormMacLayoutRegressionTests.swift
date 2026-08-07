import Foundation
import Testing

struct TaskFormMacLayoutRegressionTests {
    @Test
    func eligibleOneOffTasksShowAutoAssumeDoneBesideTheirAvailabilityControls() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormMacCards.swift"
        )
        let schedulingMainColumn = try Self.sourceSection(
            startingAt: "private var schedulingMainColumn: some View",
            endingAt: "private var schedulingSupportColumn: some View",
            in: source
        )

        #expect(
            schedulingMainColumn.contains(
                """
                if model.taskType.wrappedValue == .todo {
                                availabilityControl

                                if showsAssumedDoneControl {
                                    assumedDoneControl
                                }
                """
            )
        )
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
