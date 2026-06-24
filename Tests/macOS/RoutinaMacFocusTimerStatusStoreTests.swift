import SwiftData
import XCTest
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
final class RoutinaMacFocusTimerStatusStoreTests: XCTestCase {
    func testTogglePauseResumeUpdatesActiveTaskFocus() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.mainContext
        let task = makeTask(in: context, name: "Write", interval: 1, lastDone: nil, emoji: nil)
        let startedAt = makeDate("2026-06-24T08:00:00Z")
        let pausedAt = makeDate("2026-06-24T08:10:00Z")
        let resumedAt = makeDate("2026-06-24T08:30:00Z")

        let session = try FocusSessionSupport.startTaskFocus(
            task: task,
            startedAt: startedAt,
            plannedDurationSeconds: 0,
            context: context
        )
        let store = RoutinaMacFocusTimerStatusStore(persistence: persistence)

        XCTAssertEqual(store.status.id, session.id)
        XCTAssertTrue(store.status.supportsPauseResume)
        XCTAssertFalse(store.status.isPaused)

        XCTAssertTrue(try store.togglePauseResume(for: store.status, at: pausedAt))
        XCTAssertTrue(store.status.isPaused)
        XCTAssertEqual(store.status.pausedAt, pausedAt)

        XCTAssertTrue(try store.togglePauseResume(for: store.status, at: resumedAt))
        XCTAssertFalse(store.status.isPaused)
        XCTAssertEqual(store.status.accumulatedPausedSeconds, 20 * 60)

        let savedSession = try XCTUnwrap(try context.fetch(FetchDescriptor<FocusSession>()).first)
        XCTAssertNil(savedSession.pausedAt)
        XCTAssertEqual(savedSession.accumulatedPausedSeconds, 20 * 60)
    }

    func testSprintFocusStatusDoesNotExposeDirectPauseResume() {
        let status = RoutinaMacFocusTimerStatus(
            id: UUID(),
            targetID: UUID(),
            kind: .sprint,
            title: "Board focus",
            startedAt: Date(timeIntervalSince1970: 0),
            plannedDurationSeconds: 0,
            pausedAt: nil,
            accumulatedPausedSeconds: 0
        )

        XCTAssertEqual(status.focusSessionKind, .sprint)
        XCTAssertFalse(status.supportsPauseResume)
    }
}
