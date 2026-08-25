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
