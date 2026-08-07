import Foundation
import Testing

struct TaskDetailMacHeaderControlLayoutTests {
    @Test
    func pressureAndThinkingNeededShareOneAdaptiveLayoutForEveryTaskType() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let sharedControls = try Self.sourceSection(
            startingAt: "private var taskDetailStatusControls: some View",
            endingAt: "private var shouldShowTaskDetailStatusControls: Bool",
            in: source
        )
        let todoControls = try Self.sourceSection(
            startingAt: "private var todoHeaderControls: some View",
            endingAt: "private var taskDetailStatusControls: some View",
            in: source
        )
        let routineControls = try Self.sourceSection(
            startingAt: "private var routineHeaderControls: some View",
            endingAt: "private var taskDetailContent: some View",
            in: source
        )

        #expect(sharedControls.contains("ViewThatFits(in: .horizontal)"))
        #expect(sharedControls.contains("TaskDetailPressureSegmentedPicker(store: store)"))
        #expect(sharedControls.contains("TaskDetailThinkingNeededSegmentedPicker(store: store)"))
        #expect(sharedControls.contains(".frame(minWidth: 300)"))
        #expect(todoControls.contains("taskDetailStatusControls"))
        #expect(routineControls.contains("taskDetailStatusControls"))
        #expect(!routineControls.contains("TaskDetailPressureSegmentedPicker"))
        #expect(!routineControls.contains("TaskDetailThinkingNeededSegmentedPicker"))
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
