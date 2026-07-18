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
}
