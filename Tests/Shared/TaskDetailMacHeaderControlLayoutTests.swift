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

    @Test
    func tagsAndFlagsShareOneAdaptiveNeutralMacMetadataCard() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailMacHeaderSupplementaryContent.swift"
        )
        let body = try Self.sourceSection(
            startingAt: "var body: some View",
            endingAt: "@ViewBuilder\n    private var metadataRow",
            in: source
        )
        let metadataRow = try Self.sourceSection(
            startingAt: "private var metadataRow: some View",
            endingAt: "private func labelsBox",
            in: source
        )
        let labelsBox = try Self.sourceSection(
            startingAt: "private func labelsBox",
            endingAt: "private func singleLineLabelsRow",
            in: source
        )
        let singleLineRow = try Self.sourceSection(
            startingAt: "private func singleLineLabelsRow",
            endingAt: "private func wrappedLabelsRows",
            in: source
        )
        let wrappedRows = try Self.sourceSection(
            startingAt: "private func wrappedLabelsRows",
            endingAt: "private func labelsHeading",
            in: source
        )

        #expect(body.contains("metadataRow"))
        #expect(!body.contains("flagsBox"))
        #expect(metadataRow.contains("let hasLabels = !task.tags.isEmpty || !flags.isEmpty"))
        #expect(metadataRow.contains("labelsBox(flags: flags)"))
        #expect(labelsBox.contains("ViewThatFits(in: .horizontal)"))
        #expect(labelsBox.contains("singleLineLabelsRow(flags: flags)"))
        #expect(labelsBox.contains("wrappedLabelsRows(flags: flags)"))
        #expect(labelsBox.contains(".detailHeaderBoxStyle(minHeight: minHeight)"))
        #expect(!labelsBox.contains("detailHeaderBoxStyle(tint: .orange"))
        #expect(singleLineRow.contains("HStack(alignment: .center, spacing: 10)"))
        #expect(singleLineRow.contains("labelsHeading(\"TAGS\")"))
        #expect(singleLineRow.contains("labelsHeading(\"FLAGS\")"))
        #expect(singleLineRow.contains(".fixedSize(horizontal: true, vertical: true)"))
        #expect(!singleLineRow.contains("HomeFilterFlowLayout"))
        #expect(wrappedRows.contains("VStack(alignment: .leading, spacing: 10)"))
        #expect(wrappedRows.contains("labelsHeading(\"TAGS\")"))
        #expect(wrappedRows.contains("labelsHeading(\"FLAGS\")"))
        #expect(wrappedRows.contains("HomeFilterFlowLayout"))
        #expect(wrappedRows.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(wrappedRows.contains("Divider()"))
        #expect(wrappedRows.contains("TaskDetailFlagChip(flag: flag)"))
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
