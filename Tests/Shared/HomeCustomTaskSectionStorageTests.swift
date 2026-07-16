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
