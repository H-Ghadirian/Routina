import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeCustomTaskSectionStorageTests {
    @Test
    func renamingSectionUpdatesTitleAndPreservesSectionIdentity() throws {
        let renamedID = UUID()
        let keptID = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let sections = [
            HomeCustomTaskSection(id: renamedID, title: "Work", createdAt: createdAt),
            HomeCustomTaskSection(id: keptID, title: "Personal", createdAt: nil)
        ]

        let updatedSections = try #require(
            HomeCustomTaskSectionStorage.renamingSection(
                renamedID,
                title: "  Deep   Work  ",
                in: sections
            )
        )

        #expect(updatedSections.map(\.id) == [renamedID, keptID])
        #expect(updatedSections.map(\.title) == ["Deep Work", "Personal"])
        #expect(updatedSections.first?.createdAt == createdAt)
    }

    @Test
    func renamingSectionRejectsDuplicateNormalizedTitle() {
        let renamedID = UUID()
        let keptID = UUID()
        let sections = [
            HomeCustomTaskSection(id: renamedID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(id: keptID, title: "Personal", createdAt: nil)
        ]

        let updatedSections = HomeCustomTaskSectionStorage.renamingSection(
            renamedID,
            title: "personal",
            in: sections
        )

        #expect(updatedSections == nil)
    }

    @Test
    func deletingSectionRemovesMatchingSectionAndSanitizesRemainingCatalog() {
        let deletedID = UUID()
        let keptID = UUID()
        let sections = [
            HomeCustomTaskSection(id: deletedID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(id: keptID, title: "Personal", createdAt: nil),
            HomeCustomTaskSection(id: keptID, title: "Duplicate", createdAt: nil)
        ]

        let updatedSections = HomeCustomTaskSectionStorage.deletingSection(deletedID, from: sections)

        #expect(updatedSections.map(\.id) == [keptID])
        #expect(updatedSections.map(\.title) == ["Personal"])
    }

    @Test
    func decodingLegacySectionWithoutRulesDefaultsToManualOnly() {
        let sectionID = UUID()
        let rawValue = """
        [{"id":"\(sectionID.uuidString)","title":"Work","createdAt":null}]
        """

        let sections = HomeCustomTaskSectionStorage.decoded(from: rawValue)

        #expect(sections.count == 1)
        #expect(sections.first?.id == sectionID)
        #expect(sections.first?.rules.isEmpty == true)
        #expect(sections.first?.colorHex == nil)
    }

    @Test
    func settingColorSanitizesHexAndPreservesOtherMetadata() throws {
        let sectionID = UUID()
        let sections = [
            HomeCustomTaskSection(
                id: sectionID,
                title: "Work",
                createdAt: nil,
                rules: HomeCustomTaskSectionRules(enabledRules: [.plannedToday])
            )
        ]

        let updatedSections = try #require(
            HomeCustomTaskSectionStorage.settingColor(
                "  #11aaCC  ",
                for: sectionID,
                in: sections
            )
        )

        #expect(updatedSections.first?.colorHex == "#11AACC")
        #expect(updatedSections.first?.rules.contains(.plannedToday) == true)
        #expect(
            HomeCustomTaskSectionStorage.settingColor(
                nil,
                for: sectionID,
                in: updatedSections
            )?.first?.colorHex == nil
        )
    }

    @Test
    func settingRulePreservesSectionIdentityAndTitle() throws {
        let sectionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let sections = [
            HomeCustomTaskSection(id: sectionID, title: "Tracking", createdAt: createdAt)
        ]

        let updatedSections = try #require(
            HomeCustomTaskSectionStorage.settingRule(
                .tracking,
                isEnabled: true,
                for: sectionID,
                in: sections
            )
        )

        #expect(updatedSections.map(\.id) == [sectionID])
        #expect(updatedSections.first?.title == "Tracking")
        #expect(updatedSections.first?.createdAt == createdAt)
        #expect(updatedSections.first?.rules.contains(.tracking) == true)
    }

    @Test
    func settingTagNamesSanitizesAndDeduplicatesTags() throws {
        let sectionID = UUID()
        let sections = [
            HomeCustomTaskSection(id: sectionID, title: "Work", createdAt: nil)
        ]

        let updatedSections = try #require(
            HomeCustomTaskSectionStorage.settingTagNames(
                ["  Deep   Work  ", "deep work", "Focus", ""],
                for: sectionID,
                in: sections
            )
        )

        #expect(updatedSections.first?.rules.tagNames == ["Deep Work", "Focus"])
    }

    @Test
    func encodedRulesRoundTripInStableRuleOrder() throws {
        let sectionID = UUID()
        let rawValue = HomeCustomTaskSectionStorage.encoded([
            HomeCustomTaskSection(
                id: sectionID,
                title: "Today",
                createdAt: nil,
                rules: HomeCustomTaskSectionRules(
                    enabledRules: [.tracking, .plannedToday],
                    tagNames: ["Work", "Focus"]
                )
            )
        ])

        let decodedSection = try #require(HomeCustomTaskSectionStorage.decoded(from: rawValue).first)

        #expect(decodedSection.id == sectionID)
        #expect(decodedSection.rules.contains(.plannedToday))
        #expect(decodedSection.rules.contains(.tracking))
        #expect(!decodedSection.rules.contains(.plannedTomorrow))
        #expect(decodedSection.rules.tagNames == ["Work", "Focus"])
    }
}
