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
        #expect(functionSource.contains("HomeStatusBadgeView(style: statusBadgeStyle)"))
        #expect(functionSource.contains("showsFlags: rowVisibility.shows(.flags)"))
        #expect(functionSource.contains("showsGoals: rowVisibility.shows(.goals)"))
        #expect(functionSource.contains(".lineLimit(rowVisibility.allowsMultilineTitles ? nil : 1)"))
        #expect(functionSource.contains("vertical: rowVisibility.allowsMultilineTitles"))
    }

    @Test
    func unifiedSecondaryLabelRowRendersTagsFlagsAndGoals() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"
        )

        #expect(source.contains("ForEach(task.tags, id: \\.self)"))
        #expect(source.contains("ForEach(task.flags, id: \\.self)"))
        #expect(source.contains("ForEach(task.goalTitles, id: \\.self)"))
        #expect(source.contains("Label(flag, systemImage: \"flag.fill\")"))
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
