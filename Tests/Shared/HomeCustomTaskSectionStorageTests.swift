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
        #expect(sections.first?.parentSectionID == nil)
        #expect(sections.first?.rules.isEmpty == true)
        #expect(sections.first?.colorHex == nil)
        #expect(sections.first?.isPaused == false)
        #expect(sections.first?.pausedTaskIDs == [])
    }

    @Test
    func pausingSuperSectionTracksOnlyTasksPausedByTheSection() throws {
        let workID = UUID()
        let projectsID = UUID()
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let pausedAt = makeDate("2026-08-08T09:00:00Z")
        let sections = [
            HomeCustomTaskSection(id: workID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(
                id: projectsID,
                parentSectionID: workID,
                title: "Projects",
                createdAt: nil
            )
        ]

        let pausedSections = try #require(
            HomeCustomTaskSectionStorage.pausingSuperSection(
                workID,
                taskIDs: [firstTaskID, secondTaskID, firstTaskID],
                at: pausedAt,
                in: sections
            )
        )
        let pausedSuperSection = try #require(pausedSections.first { $0.id == workID })
        let subsection = try #require(pausedSections.first { $0.id == projectsID })

        #expect(pausedSuperSection.pausedAt == pausedAt)
        #expect(pausedSuperSection.pausedTaskIDs == [firstTaskID, secondTaskID])
        #expect(subsection.isPaused == false)
        #expect(subsection.pausedTaskIDs == [])
        #expect(
            HomeCustomTaskSectionStorage.pausingSuperSection(
                projectsID,
                taskIDs: [firstTaskID],
                at: pausedAt,
                in: sections
            ) == nil
        )

        let resumedSections = try #require(
            HomeCustomTaskSectionStorage.resumingSuperSection(workID, in: pausedSections)
        )
        let resumedSuperSection = try #require(resumedSections.first { $0.id == workID })
        #expect(resumedSuperSection.isPaused == false)
        #expect(resumedSuperSection.pausedTaskIDs == [])
    }

    @Test
    func subsectionRoundTripsAndIsScopedToItsSuperSection() throws {
        let workID = UUID()
        let personalID = UUID()
        let sections = [
            HomeCustomTaskSection(id: workID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(
                parentSectionID: workID,
                title: "Projects",
                createdAt: nil
            ),
            HomeCustomTaskSection(id: personalID, title: "Personal", createdAt: nil),
            HomeCustomTaskSection(
                parentSectionID: personalID,
                title: "Projects",
                createdAt: nil
            )
        ]

        let decoded = HomeCustomTaskSectionStorage.decoded(
            from: HomeCustomTaskSectionStorage.encoded(sections)
        )

        #expect(HomeCustomTaskSectionStorage.topLevelSections(in: decoded).map(\.id) == [workID, personalID])
        #expect(HomeCustomTaskSectionStorage.subsections(of: workID, in: decoded).map(\.title) == ["Projects"])
        #expect(HomeCustomTaskSectionStorage.subsections(of: personalID, in: decoded).map(\.title) == ["Projects"])
    }

    @Test
    func pathTitlesResolveSuperSectionsAndSubsections() {
        let workID = UUID()
        let projectsID = UUID()
        let sections = [
            HomeCustomTaskSection(id: workID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(
                id: projectsID,
                parentSectionID: workID,
                title: "Projects",
                createdAt: nil
            )
        ]

        #expect(HomeCustomTaskSectionStorage.pathTitles(for: workID, in: sections) == ["Work"])
        #expect(
            HomeCustomTaskSectionStorage.pathTitles(for: projectsID, in: sections)
                == ["Work", "Projects"]
        )
        #expect(HomeCustomTaskSectionStorage.pathTitles(for: UUID(), in: sections) == nil)
    }

    @Test
    func deletingSuperSectionAlsoDeletesItsSubsections() {
        let workID = UUID()
        let workChildID = UUID()
        let personalID = UUID()
        let sections = [
            HomeCustomTaskSection(id: workID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(
                id: workChildID,
                parentSectionID: workID,
                title: "Projects",
                createdAt: nil
            ),
            HomeCustomTaskSection(id: personalID, title: "Personal", createdAt: nil)
        ]

        let updated = HomeCustomTaskSectionStorage.deletingSection(workID, from: sections)

        #expect(updated.map(\.id) == [personalID])
        #expect(
            HomeCustomTaskSectionStorage.sectionAndDescendantIDs(for: workID, in: sections)
                == [workID, workChildID]
        )
    }

    @Test
    func movingSectionsReordersOnlyWithinTheirHierarchyLevel() throws {
        let workID = UUID()
        let projectsID = UUID()
        let errandsID = UUID()
        let personalID = UUID()
        let sections = [
            HomeCustomTaskSection(id: workID, title: "Work", createdAt: nil),
            HomeCustomTaskSection(
                id: projectsID,
                parentSectionID: workID,
                title: "Projects",
                createdAt: nil
            ),
            HomeCustomTaskSection(id: personalID, title: "Personal", createdAt: nil),
            HomeCustomTaskSection(
                id: errandsID,
                parentSectionID: workID,
                title: "Errands",
                createdAt: nil
            )
        ]

        let reorderedTopLevel = try #require(
            HomeCustomTaskSectionStorage.movingSection(
                personalID,
                by: -1,
                in: sections
            )
        )
        let reorderedSubsections = try #require(
            HomeCustomTaskSectionStorage.movingSection(
                errandsID,
                by: -1,
                in: sections
            )
        )

        #expect(
            HomeCustomTaskSectionStorage.topLevelSections(in: reorderedTopLevel).map(\.id)
                == [personalID, workID]
        )
        #expect(
            HomeCustomTaskSectionStorage.subsections(of: workID, in: reorderedTopLevel).map(\.id)
                == [projectsID, errandsID]
        )
        #expect(
            HomeCustomTaskSectionStorage.topLevelSections(in: reorderedSubsections).map(\.id)
                == [workID, personalID]
        )
        #expect(
            HomeCustomTaskSectionStorage.subsections(of: workID, in: reorderedSubsections).map(\.id)
                == [errandsID, projectsID]
        )
        #expect(
            HomeCustomTaskSectionStorage.movingSection(
                workID,
                by: -1,
                in: sections
            ) == nil
        )
    }

    @Test
    func syncingPersistencePreservesUnsavedLocalDrafts() {
        let sectionID = UUID()
        let original = HomeCustomTaskSection(
            id: sectionID,
            title: "Work",
            createdAt: nil,
            rules: HomeCustomTaskSectionRules(tagNames: ["Focus"])
        )
        var state = HomeCustomTaskSectionDraftState()
        state.sync(with: [original])
        state.titleDrafts[sectionID] = "Deep Work"
        state.tagRuleDrafts[sectionID] = "Focus, Urgent"

        let colorOnlyUpdate = HomeCustomTaskSection(
            id: sectionID,
            title: "Work",
            createdAt: nil,
            rules: HomeCustomTaskSectionRules(tagNames: ["Focus"]),
            colorHex: "#FF453A"
        )
        state.sync(with: [colorOnlyUpdate])

        #expect(state.titleDrafts[sectionID] == "Deep Work")
        #expect(state.tagRuleDrafts[sectionID] == "Focus, Urgent")
    }

    @Test
    func syncingPersistenceAdoptsExternalValuesWhenDraftsAreUnchanged() {
        let sectionID = UUID()
        let original = HomeCustomTaskSection(
            id: sectionID,
            title: "Work",
            createdAt: nil,
            rules: HomeCustomTaskSectionRules(tagNames: ["Focus"])
        )
        var state = HomeCustomTaskSectionDraftState()
        state.sync(with: [original])

        let externalUpdate = HomeCustomTaskSection(
            id: sectionID,
            title: "Studio",
            createdAt: nil,
            rules: HomeCustomTaskSectionRules(tagNames: ["Creative"])
        )
        state.sync(with: [externalUpdate])

        #expect(state.titleDrafts[sectionID] == "Studio")
        #expect(state.tagRuleDrafts[sectionID] == "Creative")
    }

    @Test
    func settingColorSanitizesHexAndPreservesOtherMetadata() throws {
        let sectionID = UUID()
        let sections = [
            HomeCustomTaskSection(
                id: sectionID,
                title: "Work",
                createdAt: nil,
                rules: HomeCustomTaskSectionRules(tagNames: ["Focus"])
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
        #expect(updatedSections.first?.rules.tagNames == ["Focus"])
        #expect(
            HomeCustomTaskSectionStorage.settingColor(
                nil,
                for: sectionID,
                in: updatedSections
            )?.first?.colorHex == nil
        )
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
    func tagRulesCanMatchAnyOrAllConfiguredTags() {
        let anyRules = HomeCustomTaskSectionRules(
            tagNames: ["Work", "Deep Focus"],
            tagMatchMode: .any
        )
        let allRules = HomeCustomTaskSectionRules(
            tagNames: ["Work", "Deep Focus"],
            tagMatchMode: .all
        )

        #expect(anyRules.matchesTags(["work"]))
        #expect(anyRules.matchesTags(["Deep Focus"]))
        #expect(!anyRules.matchesTags(["Home"]))
        #expect(allRules.matchesTags(["deep focus", "WORK", "Other"]))
        #expect(!allRules.matchesTags(["Work"]))
        #expect(!HomeCustomTaskSectionRules(tagMatchMode: .all).matchesTags([]))
    }

    @Test
    func settingTagMatchModePreservesTagsAndOtherSectionMetadata() throws {
        let sectionID = UUID()
        let sections = [
            HomeCustomTaskSection(
                id: sectionID,
                title: "Work",
                createdAt: nil,
                rules: HomeCustomTaskSectionRules(tagNames: ["Focus"]),
                colorHex: "#FF453A"
            )
        ]

        let updatedSections = try #require(
            HomeCustomTaskSectionStorage.settingTagMatchMode(
                .all,
                for: sectionID,
                in: sections
            )
        )

        #expect(updatedSections.first?.rules.tagMatchMode == .all)
        #expect(updatedSections.first?.rules.tagNames == ["Focus"])
        #expect(updatedSections.first?.colorHex == "#FF453A")

        let retaggedSections = try #require(
            HomeCustomTaskSectionStorage.settingTagNames(
                ["Planning"],
                for: sectionID,
                in: updatedSections
            )
        )
        #expect(retaggedSections.first?.rules.tagMatchMode == .all)
        #expect(retaggedSections.first?.rules.tagNames == ["Planning"])
    }

    @Test
    func legacyPlannedRulesDecodeAsTagOnlyAndAreNotReencoded() throws {
        let sectionID = UUID()
        let rawValue = """
        [{
          "id":"\(sectionID.uuidString)",
          "title":"Today",
          "createdAt":null,
          "rules":{
            "enabled":["plannedTomorrow","plannedToday"],
            "tags":["Work","Focus"]
          }
        }]
        """

        let decodedSection = try #require(HomeCustomTaskSectionStorage.decoded(from: rawValue).first)
        let reencoded = HomeCustomTaskSectionStorage.encoded([decodedSection])

        #expect(decodedSection.id == sectionID)
        #expect(decodedSection.rules.tagNames == ["Work", "Focus"])
        #expect(decodedSection.rules.tagMatchMode == .any)
        #expect(!reencoded.contains("\"enabled\""))
    }
}
