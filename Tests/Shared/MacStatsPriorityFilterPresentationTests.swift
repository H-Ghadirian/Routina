import Foundation
import Testing

struct MacStatsPriorityFilterPresentationTests {
    @Test
    func statsSidebarUsesSeparateImportanceAndUrgencySections() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarView.swift"
        )

        #expect(source.contains("HomeMacStatsImportanceFilterSection("))
        #expect(source.contains("HomeMacStatsUrgencyFilterSection("))
        #expect(!source.contains("HomeMacImportanceUrgencyDisclosureSection("))
    }

    @Test
    func separateSectionsOnlyUpdateTheirOwnThreshold() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(source.contains("ImportanceUrgencyFilterCell.updatingMinimumImportance("))
        #expect(source.contains("ImportanceUrgencyFilterCell.updatingMinimumUrgency("))
    }

    @Test
    func singleChoiceSectionsUseInlineMenuPickersWithoutExpansionState() throws {
        let sidebar = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarView.swift"
        )
        let sections = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(!sidebar.contains("expandedSingleChoiceSection"))
        #expect(!sidebar.contains("expansionBinding"))
        #expect(sections.contains("struct HomeMacStatsInlinePickerSection"))
        #expect(sections.components(separatedBy: "HomeMacStatsInlinePickerSection(").count == 6)
        #expect(sections.components(separatedBy: ".pickerStyle(.menu)").count == 2)
        #expect(!sections.contains("RoutinaGlassSegmentedControl"))
    }

    @Test
    func customRangeSelectionRevealsOnlyItsDateEditor() throws {
        let sections = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(sections.contains("Text(\"Custom…\").tag(DoneChartRange.Kind.custom.rawValue)"))
        #expect(sections.contains("if selectedRange.kind == .custom"))
        #expect(sections.contains("DatePicker(\"From\""))
        #expect(sections.contains("DatePicker(\"Through\""))
        #expect(sections.contains("onSelectRange(.custom(from: customStart, through: customEnd))"))
        #expect(!sections.contains("onPresetSelectionComplete"))
    }

    @Test
    func inlinePickerCardsKeepPassiveTintedCardPresentation() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(source.contains(".controlSize(.large)"))
        #expect(source.contains(".frame(width: 124)"))
        #expect(source.contains("tintOpacity: 0.08"))
        #expect(source.contains(".strokeBorder(tint.opacity(0.18), lineWidth: 1)"))
    }

    @Test
    func inlinePickersRetainAccessibleLabelsWhileHidingDuplicateVisualLabels() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(source.contains("Picker(\"Stats scope\""))
        #expect(source.contains("Picker(\"Stats task type\""))
        #expect(source.contains("Picker(\"Stats time range\""))
        #expect(source.contains("Picker(\"Minimum importance\""))
        #expect(source.contains("Picker(\"Minimum urgency\""))
        #expect(source.contains(".labelsHidden()"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
