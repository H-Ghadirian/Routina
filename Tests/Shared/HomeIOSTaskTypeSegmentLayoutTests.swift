import Foundation
import Testing

struct HomeIOSFilterChoiceRowLayoutTests {
    @Test
    func taskTypeAndOneTimeStateUseGroupedRows() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")
        let taskTypeSection = try Self.sourceSection(
            startingAt: "case .homeTaskType:",
            endingAt: "case .visibility:",
            in: source
        )
        let oneTimeStateSection = try Self.sourceSection(
            startingAt: "case .todoState:",
            endingAt: "case .pressure:",
            in: source
        )

        #expect(taskTypeSection.contains("Picker(\"Task type\""))
        #expect(taskTypeSection.contains("Label(mode.title, systemImage: mode.systemImage)"))
        #expect(taskTypeSection.contains(".pickerStyle(.inline)"))
        #expect(taskTypeSection.contains(".labelsHidden()"))
        #expect(!taskTypeSection.contains("RoutinaGlassSegmentedControl"))

        #expect(oneTimeStateSection.contains("Picker(\"One-time state\""))
        #expect(oneTimeStateSection.contains("Label(\"Any state\", systemImage: \"square.grid.2x2\")"))
        #expect(oneTimeStateSection.contains("ForEach(TodoState.filterableCases)"))
        #expect(oneTimeStateSection.contains("Label(state.displayTitle, systemImage: state.systemImage)"))
        #expect(oneTimeStateSection.contains(".pickerStyle(.inline)"))
        #expect(oneTimeStateSection.contains(".labelsHidden()"))
        #expect(!oneTimeStateSection.contains("HomeTodoStateFilterChips"))
    }

    @Test
    func priorityDetailsUseGroupedRowsAndExplainSelectionSemantics() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")
        let listSections = try Self.sourceFile("iOS/Screens/Home/HomeFiltersListSections.swift")
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
        let importanceSection = try Self.sourceSection(
            startingAt: "struct HomeFiltersImportancePickerSheet",
            endingAt: "struct HomeFiltersUrgencyPickerSheet",
            in: listSections
        )
        let urgencySection = try Self.sourceSection(
            startingAt: "struct HomeFiltersUrgencyPickerSheet",
            endingAt: "struct HomeFiltersPlaceSection",
            in: listSections
        )

        for (section, title) in [
            (pressureSection, "Pressure"),
            (thinkingSection, "Thinking needed")
        ] {
            #expect(section.contains("Picker(\"\(title)\""))
            #expect(section.contains(".pickerStyle(.inline)"))
            #expect(section.contains(".labelsHidden()"))
            #expect(section.contains("All does not filter"))
            #expect(section.contains("None shows tasks without a recorded"))
            #expect(!section.contains("RoutinaGlassSegmentedControl"))
        }

        #expect(importanceSection.contains("Picker(\"Minimum importance\""))
        #expect(importanceSection.contains("return \"Medium or higher\""))
        #expect(importanceSection.contains("return \"High or higher\""))
        #expect(importanceSection.contains("return \"Critical only\""))
        #expect(importanceSection.contains(".pickerStyle(.inline)"))
        #expect(!importanceSection.contains("RoutinaGlassSegmentedControl"))

        #expect(urgencySection.contains("Picker(\"Minimum urgency\""))
        #expect(urgencySection.contains("return \"Medium or higher\""))
        #expect(urgencySection.contains("return \"High or higher\""))
        #expect(urgencySection.contains("return \"Immediate only\""))
        #expect(urgencySection.contains(".pickerStyle(.inline)"))
        #expect(!urgencySection.contains("RoutinaGlassSegmentedControl"))
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
