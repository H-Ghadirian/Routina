import Foundation
import Testing

struct TaskFormIOSLayoutRegressionTests {
    @Test
    func taskTypeUsesSeparateSectionsWithoutSpacerRows() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSIdentitySections.swift"
        )
        let taskTypeSection = try Self.sourceSection(
            startingAt: "struct TaskFormIOSTaskTypeSection",
            endingAt: "struct TaskFormIOSEmojiSection",
            in: source
        )

        #expect(taskTypeSection.contains("Section(header: Text(\"Task Type\"))"))
        #expect(taskTypeSection.contains("Section(header: Text(\"Duration\"))"))
        #expect(taskTypeSection.contains("Section(header: Text(\"Availability\"))"))
        #expect(!taskTypeSection.contains("Divider()"))
    }

    @Test
    func availabilityUsesReadableNavigationChoicesInsteadOfFiveSegments() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSIdentitySections.swift"
        )
        let taskTypeSection = try Self.sourceSection(
            startingAt: "struct TaskFormIOSTaskTypeSection",
            endingAt: "struct TaskFormIOSEmojiSection",
            in: source
        )

        #expect(taskTypeSection.contains("Picker(\"Dates\""))
        #expect(taskTypeSection.contains("Picker(\"Time\""))
        #expect(taskTypeSection.contains(".pickerStyle(.navigationLink)"))
        #expect(!taskTypeSection.contains("accessibilityLabel: \"Time availability\""))
    }

    @Test
    func progressiveDetailsRevealOneChosenSectionAndScrollToIt() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormContentPlatform.swift"
        )

        #expect(source.contains("@State private var revealedSections"))
        #expect(source.contains("Label(\"Add details\", systemImage: \"plus.circle.fill\")"))
        #expect(source.contains("_ = revealedSections.insert(section)"))
        #expect(source.contains("proxy.scrollTo(section, anchor: .top)"))
        #expect(source.contains(".frame(maxWidth: .infinity, minHeight: 44"))
        #expect(source.contains(".contentShape(.rect)"))
        #expect(!source.contains("isShowingMoreDetails.toggle()"))
    }

    @Test
    func descriptionIsIndependentFromExperimentalNotesAndSupportsTargetedReveal() throws {
        let formSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let textSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSTextSections.swift"
        )
        let detailSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )

        #expect(textSource.contains("struct TaskFormIOSDescriptionSection"))
        #expect(formSource.contains("case .taskDescription:\n            taskDescriptionSection"))
        #expect(formSource.contains("_revealedSections = State(initialValue: model.initiallyRevealedCompactSections)"))
        #expect(formSource.contains("case .notes, .voiceNote:\n                return isNotesEnabled"))
        #expect(detailSource.contains("requestedEditSection = .taskDescription"))
        #expect(detailSource.contains("taskDescription: store.task.taskDescription"))
    }

    @Test
    func linkTaskPickerKeepsDesktopMinimumSizeOutOfIOSSheets() throws {
        let source = try Self.sourceFile(
            "SharedCore/Views/TaskRelationshipsEditor.swift"
        )
        let picker = try Self.sourceSection(
            startingAt: "struct TaskRelationshipPickerSheet",
            endingAt: "private var taskSearchField",
            in: source
        )

        #expect(picker.contains("#if os(macOS)\n            .frame(minWidth: 520, minHeight: 420)\n#endif"))
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
