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
    func parsesTaskGoalNoteEventAndSprintLinks() throws {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let eventID = UUID()
        let sprintID = UUID()
        let sleepID = UUID()

        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://task/\(taskID.uuidString)"))) == .task(taskID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://goal/\(goalID.uuidString)"))) == .goal(goalID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://note/\(noteID.uuidString)"))) == .note(noteID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://event/\(eventID.uuidString)"))) == .event(eventID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://sprint/\(sprintID.uuidString)"))) == .sprint(sprintID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina://sleep/\(sleepID.uuidString)"))) == .sleep(sleepID))
    }

    @Test
    func parsesDevSchemeLinks() throws {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let eventID = UUID()
        let sprintID = UUID()
        let sleepID = UUID()

        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina-dev://task/\(taskID.uuidString)"))) == .task(taskID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina-dev://goal/\(goalID.uuidString)"))) == .goal(goalID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina-dev://note/\(noteID.uuidString)"))) == .note(noteID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina-dev://event/\(eventID.uuidString)"))) == .event(eventID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina-dev://sprint/\(sprintID.uuidString)"))) == .sprint(sprintID))
        #expect(RoutinaDeepLink(url: try #require(URL(string: "routina-dev://sleep/\(sleepID.uuidString)"))) == .sleep(sleepID))
    }

    @Test
    func createsStableEntityURLs() {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let eventID = UUID()
        let sprintID = UUID()
        let sleepID = UUID()
        let scheme = AppEnvironment.deepLinkURLScheme

        #expect(RoutinaDeepLink.task(taskID).url.absoluteString == "\(scheme)://task/\(taskID.uuidString)")
        #expect(RoutinaDeepLink.goal(goalID).url.absoluteString == "\(scheme)://goal/\(goalID.uuidString)")
        #expect(RoutinaDeepLink.note(noteID).url.absoluteString == "\(scheme)://note/\(noteID.uuidString)")
        #expect(RoutinaDeepLink.event(eventID).url.absoluteString == "\(scheme)://event/\(eventID.uuidString)")
        #expect(RoutinaDeepLink.sprint(sprintID).url.absoluteString == "\(scheme)://sprint/\(sprintID.uuidString)")
        #expect(RoutinaDeepLink.sleep(sleepID).url.absoluteString == "\(scheme)://sleep/\(sleepID.uuidString)")
    }

    @Test
    func createsProductionEntityURLsWhenRequested() {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let eventID = UUID()
        let sprintID = UUID()
        let sleepID = UUID()
        let scheme = AppEnvironment.productionDeepLinkURLScheme

        #expect(RoutinaDeepLink.task(taskID).url(scheme: scheme).absoluteString == "routina://task/\(taskID.uuidString)")
        #expect(RoutinaDeepLink.goal(goalID).url(scheme: scheme).absoluteString == "routina://goal/\(goalID.uuidString)")
        #expect(RoutinaDeepLink.note(noteID).url(scheme: scheme).absoluteString == "routina://note/\(noteID.uuidString)")
        #expect(RoutinaDeepLink.event(eventID).url(scheme: scheme).absoluteString == "routina://event/\(eventID.uuidString)")
        #expect(RoutinaDeepLink.sprint(sprintID).url(scheme: scheme).absoluteString == "routina://sprint/\(sprintID.uuidString)")
        #expect(RoutinaDeepLink.sleep(sleepID).url(scheme: scheme).absoluteString == "routina://sleep/\(sleepID.uuidString)")
    }

    @Test
    func createsDevEntityURLsWhenRequested() {
        let taskID = UUID()
        let goalID = UUID()
        let noteID = UUID()
        let eventID = UUID()
        let sprintID = UUID()
        let sleepID = UUID()
        let scheme = AppEnvironment.sandboxDeepLinkURLScheme

        #expect(RoutinaDeepLink.task(taskID).url(scheme: scheme).absoluteString == "routina-dev://task/\(taskID.uuidString)")
        #expect(RoutinaDeepLink.goal(goalID).url(scheme: scheme).absoluteString == "routina-dev://goal/\(goalID.uuidString)")
        #expect(RoutinaDeepLink.note(noteID).url(scheme: scheme).absoluteString == "routina-dev://note/\(noteID.uuidString)")
        #expect(RoutinaDeepLink.event(eventID).url(scheme: scheme).absoluteString == "routina-dev://event/\(eventID.uuidString)")
        #expect(RoutinaDeepLink.sprint(sprintID).url(scheme: scheme).absoluteString == "routina-dev://sprint/\(sprintID.uuidString)")
        #expect(RoutinaDeepLink.sleep(sleepID).url(scheme: scheme).absoluteString == "routina-dev://sleep/\(sleepID.uuidString)")
    }
}
