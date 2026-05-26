import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutinaDeepLinkTests {
    @Test
    func parsesTaskGoalNoteAndSprintLinks() throws {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let sprintID = UUID()

        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://task/\(taskID.uuidString)"))) == .task(taskID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://goal/\(goalID.uuidString)"))) == .goal(goalID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://note/\(noteID.uuidString)"))) == .note(noteID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://sprint/\(sprintID.uuidString)"))) == .sprint(sprintID))
    }

    @Test
    func createsStableEntityURLs() {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let sprintID = UUID()

        #expect(RoutinaDeepLink.task(taskID).url.absoluteString == "routina://task/\(taskID.uuidString)")
        #expect(RoutinaDeepLink.goal(goalID).url.absoluteString == "routina://goal/\(goalID.uuidString)")
        #expect(RoutinaDeepLink.note(noteID).url.absoluteString == "routina://note/\(noteID.uuidString)")
        #expect(RoutinaDeepLink.sprint(sprintID).url.absoluteString == "routina://sprint/\(sprintID.uuidString)")
    }
}
