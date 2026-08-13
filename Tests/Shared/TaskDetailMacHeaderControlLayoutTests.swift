import Foundation
import Testing

struct TaskDetailMacHeaderControlLayoutTests {
    @Test
    func priorityControlsShareOneExpandableSectionForEveryTaskType() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let actionControls = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let prioritySection = try Self.sourceSection(
            startingAt: "private var taskDetailPrioritySection: some View",
            endingAt: "private var shouldShowTimeControl: Bool",
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

        #expect(prioritySection.contains("TaskDetailPriorityDisclosureBox("))
        #expect(prioritySection.contains("TaskDetailPriorityControlsGrid(store: store)"))
        #expect(actionControls.contains("struct TaskDetailPriorityControlsGrid"))
        #expect(actionControls.contains("ViewThatFits(in: .horizontal)"))
        #expect(actionControls.contains("TaskDetailPressureSegmentedPicker("))
        #expect(actionControls.contains("TaskDetailThinkingNeededSegmentedPicker("))
        #expect(actionControls.contains("TaskDetailImportanceSegmentedPicker("))
        #expect(actionControls.contains("TaskDetailUrgencySegmentedPicker("))
        #expect(todoControls.contains("taskDetailStatusControls"))
        #expect(todoControls.contains("taskDetailPrioritySection"))
        #expect(routineControls.contains("taskDetailStatusControls"))
        #expect(routineControls.contains("taskDetailPrioritySection"))
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
