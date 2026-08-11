import Foundation
import Testing

struct HomeIOSTaskTypeSegmentLayoutTests {
    @Test
    func compactTaskTypeSegmentsPrioritizeFullTextLabels() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")
        let section = try Self.sourceSection(
            startingAt: "case .homeTaskType:",
            endingAt: "case .visibility:",
            in: source
        )

        #expect(section.contains("minimumSegmentWidth: 82"))
        #expect(section.contains("horizontalPadding: 10"))
        #expect(section.contains("Text(mode.title)"))
        #expect(section.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(!section.contains("Label(mode.title"))
    }

    @Test
    func pressureAndThinkingFiltersWrapFiveValuesWithoutTruncatingMedium() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")
        let pressureSection = try Self.sourceSection(
            startingAt: "case .pressure:",
            endingAt: "case .thinkingNeeded:",
            in: source
        )
        let thinkingSection = try Self.sourceSection(
            startingAt: "case .thinkingNeeded:",
            endingAt: "case .goal:",
            in: source
        )

        for section in [pressureSection, thinkingSection] {
            #expect(section.contains("maximumSegmentsPerRow: 3"))
            #expect(section.contains("horizontalPadding: 10"))
            #expect(section.contains("verticalPadding: 8"))
            #expect(section.contains("fillsAvailableWidth: true"))
        }
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
