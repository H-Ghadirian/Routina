import Foundation
import Testing

struct TaskDetailMacHeaderControlLayoutTests {
    @Test
    func taskLadderValuesKeepCurrentValuesVisibleAndExpandOnePickerAtATime() throws {
        let source = try SourceInspectionSupport.readMacTaskDetailSources()
        let actionControls = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let valuesSection = try Self.sourceSection(
            startingAt: "private var taskDetailTaskLadderValuesSection: some View",
            endingAt: "private var shouldShowTimeControl: Bool",
            in: source
        )
        let todoControls = try Self.sourceSection(
            startingAt: "var todoHeaderControls: some View",
            endingAt: "private var taskDetailStatusControls: some View",
            in: source
        )
        let routineControls = try Self.sourceSection(
            startingAt: "var routineHeaderControls: some View",
            endingAt: "var taskDetailContent: some View",
            in: source
        )

        #expect(valuesSection.contains("TaskDetailTaskLadderValuesBox"))
        #expect(valuesSection.contains("TaskDetailTaskLadderValuesControlsGrid(store: store)"))
        #expect(!valuesSection.contains("isExpanded"))
        #expect(actionControls.contains("struct TaskDetailTaskLadderValuesControlsGrid"))
        #expect(actionControls.contains("ViewThatFits(in: .horizontal)"))
        #expect(actionControls.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(!actionControls.contains(".frame(minWidth: 220)"))
        #expect(actionControls.contains("@State private var expandedValue: TaskDetailExpandedTaskLadderValue?"))
        #expect(actionControls.contains("store.task.temporalWeightRule != nil"))
        #expect(actionControls.contains("struct TaskDetailExpandableSegmentedPicker"))
        #expect(actionControls.contains("if isReadOnly"))
        #expect(actionControls.contains("selectedValueLabel(showsDisclosure: false)"))
        #expect(actionControls.contains("selectedValueLabel(showsDisclosure: true)"))
        #expect(actionControls.contains("if isExpanded"))
        #expect(actionControls.contains("Text(optionTitle(selection))"))
        #expect(actionControls.contains(".transition(.taskDetailHorizontalReveal)"))
        #expect(actionControls.contains("expandedValue = expandedValue == value ? nil : value"))
        #expect(actionControls.contains("expandedValue = nil"))
        #expect(actionControls.contains("accessibilityReduceMotion"))
        #expect(actionControls.contains("TaskDetailPressureSegmentedPicker("))
        #expect(actionControls.contains("TaskDetailThinkingNeededSegmentedPicker("))
        #expect(actionControls.contains("TaskDetailImportanceSegmentedPicker("))
        #expect(actionControls.contains("TaskDetailUrgencySegmentedPicker("))
        #expect(todoControls.contains("taskDetailStatusControls"))
        #expect(todoControls.contains("taskDetailTaskLadderValuesSection"))
        #expect(routineControls.contains("taskDetailStatusControls"))
        #expect(routineControls.contains("taskDetailTaskLadderValuesSection"))
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

    @Test
    func taskContentUsesSemanticGroupsAndKeepsLinksOutOfTheMacHeader() throws {
        let headerSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailMacHeaderSupplementaryContent.swift"
        )
        let detailSource = try SourceInspectionSupport.readMacTaskDetailSources()
        let contentSource = try Self.sourceFile(
            "SharedCore/Screens/TaskDetail/TaskDetailExtrasSectionView.swift"
        )
        let extrasVisibility = try Self.sourceSection(
            startingAt: "var hasTaskExtras: Bool",
            endingAt: "var shouldShowHeatmapSection",
            in: detailSource
        )
        let extrasCard = try Self.sourceSection(
            startingAt: "var taskExtrasSection: some View",
            endingAt: "var linkedEventsSection",
            in: detailSource
        )

        #expect(!headerSource.contains("resolvedLinkURLs"))
        #expect(!headerSource.contains("Text(\"DETAILS\")"))
        #expect(extrasVisibility.contains("|| !store.task.resolvedLinkURLs.isEmpty"))
        #expect(extrasCard.contains("links: store.task.resolvedLinkURLs"))
        #expect(!extrasCard.contains("links: []"))
        #expect(!contentSource.contains("Text(\"Details\")"))

        let description = try #require(contentSource.range(of: "contentGroup(title: \"DESCRIPTION\")"))
        let links = try #require(contentSource.range(of: "contentGroup(title: \"LINKS\")"))
        let image = try #require(contentSource.range(of: "contentGroup(title: \"IMAGE\")"))
        let files = try #require(contentSource.range(of: "contentGroup(title: attachments.count == 1 ? \"FILE\" : \"FILES\")"))
        let voiceNote = try #require(contentSource.range(of: "contentGroup(title: \"VOICE NOTE\")"))
        let notes = try #require(contentSource.range(of: "contentGroup(title: \"NOTES\")"))

        #expect(description.lowerBound < links.lowerBound)
        #expect(links.lowerBound < image.lowerBound)
        #expect(image.lowerBound < files.lowerBound)
        #expect(files.lowerBound < voiceNote.lowerBound)
        #expect(voiceNote.lowerBound < notes.lowerBound)
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
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
