import Foundation
import Testing

struct HomeMacTaskRowMetadataLayoutSourceTests {
    @Test
    func titlePrecedesTheUnifiedSecondaryLabelRow() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"
        )
        let functionStart = try #require(
            source.range(of: "func platformRoutineRow(\n        for task:")
        )
        let functionEnd = try #require(
            source.range(
                of: "func assumedDoneHoverActions(",
                range: functionStart.upperBound..<source.endIndex
            )
        )
        let functionSource = String(source[functionStart.lowerBound..<functionEnd.lowerBound])
        let title = try #require(functionSource.range(of: "Text(task.name)"))
        let secondaryRow = try #require(functionSource.range(of: "if showsSecondaryLabels"))
        let metadata = try #require(functionSource.range(of: "if let metadataText"))

        #expect(title.lowerBound < secondaryRow.lowerBound)
        #expect(secondaryRow.lowerBound < metadata.lowerBound)
        #expect(functionSource.contains("statusBadgeStyle: statusBadgeStyle"))
        #expect(functionSource.contains("showsFlags: rowVisibility.shows(.flags)"))
        #expect(functionSource.contains(
            "showsGoals: isGoalsTabEnabled && rowVisibility.shows(.goals)"
        ))
        #expect(functionSource.contains(".lineLimit(rowVisibility.allowsMultilineTitles ? nil : 1)"))
        #expect(functionSource.contains("vertical: rowVisibility.allowsMultilineTitles"))
        #expect(functionSource.contains(
            "allowsMultilineDetails: rowVisibility.allowsMultilineDetails"
        ))
    }

    @Test
    func unifiedSecondaryLabelRowRendersTagsFlagsAndGoals() throws {
        let rowSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"
        )
        let labelsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacTaskRowSecondaryLabels.swift"
        )

        #expect(rowSource.contains("task.tags.map(HomeMacTaskRowSecondaryLabel.tag)"))
        #expect(rowSource.contains("task.flags.map(HomeMacTaskRowSecondaryLabel.flag)"))
        #expect(rowSource.contains("task.goalTitles.map(HomeMacTaskRowSecondaryLabel.goal)"))
        #expect(labelsSource.contains("Label(flag, systemImage: \"flag.fill\")"))
        #expect(labelsSource.contains(
            "HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 5)"
        ))
        #expect(labelsSource.contains("HomeMacTaskRowCompactLabelsLayout("))
        #expect(labelsSource.contains("ForEach(1...labels.count, id: \\.self)"))
        #expect(labelsSource.contains("Text(\"+\\(hiddenCount) more\")"))
        #expect(labelsSource.contains(".help(hiddenDescription)"))
    }

    @Test
    func taskListAppearanceExposesTheMultilineTitleOption() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift"
        )

        #expect(source.contains("HomeMacFilterAppearanceToggleRow("))
        #expect(source.contains("\"Multiline Titles\","))
        #expect(source.contains("get: { taskRowVisibility.allowsMultilineTitles }"))
        #expect(source.contains("set: { onTaskRowMultilineTitlesChanged($0) }"))
        #expect(source.contains("\"Multiline Details\","))
        #expect(source.contains("get: { taskRowVisibility.allowsMultilineDetails }"))
        #expect(source.contains("set: { onTaskRowMultilineDetailsChanged($0) }"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
