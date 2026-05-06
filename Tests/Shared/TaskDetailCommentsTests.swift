import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@Suite(.serialized)
@MainActor
struct TaskDetailCommentsTests {
    @Test
    func commentStoragePreservesInsertionOrderWhenDatesMatch() {
        let createdAt = makeDate("2026-04-02T08:15:00Z")
        let firstID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let comments = [
            RoutineTaskComment(id: firstID, body: "First", createdAt: createdAt),
            RoutineTaskComment(id: secondID, body: "Second", createdAt: createdAt)
        ]

        let restoredComments = RoutineTaskCommentStorage.deserialize(
            RoutineTaskCommentStorage.serialize(comments)
        )

        #expect(restoredComments.map(\.id) == [firstID, secondID])
    }

    @Test
    func detailComments_canAddEditAndDeleteWithoutOpeningEditSheet() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Journal", interval: 1, lastDone: nil, emoji: "J")
        let now = makeDate("2026-04-02T08:15:00Z")

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task.detachedCopy()
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
        }
        store.exhaustivity = .off

        await store.send(.detailCommentDraftChanged("First comment"))
        await store.send(.detailCommentAddTapped)

        #expect(store.state.detailCommentDraft.isEmpty)
        #expect(store.state.task.comments.map(\.body) == ["First comment"])

        await store.send(.detailCommentDraftChanged("Second comment"))
        await store.send(.detailCommentAddTapped)

        #expect(store.state.task.comments.map(\.body) == ["First comment", "Second comment"])

        let firstCommentID = try #require(store.state.task.comments.first?.id)
        let secondCommentID = try #require(store.state.task.comments.last?.id)

        await store.send(.detailCommentEditTapped(firstCommentID))
        #expect(store.state.editingDetailCommentID == firstCommentID)
        #expect(store.state.editingDetailCommentDraft == "First comment")

        await store.send(.detailCommentEditDraftChanged("Updated first comment"))
        await store.send(.detailCommentEditSaveTapped(firstCommentID))

        #expect(store.state.editingDetailCommentID == nil)
        #expect(store.state.task.comments.map(\.body) == ["Updated first comment", "Second comment"])
        #expect(store.state.task.comments.first?.updatedAt == now)

        await store.send(.detailCommentDeleteTapped(secondCommentID))

        #expect(store.state.task.comments.map(\.body) == ["Updated first comment"])

        let taskID = task.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { task in
                task.id == taskID
            }
        )
        let persistedTask = try #require(context.fetch(descriptor).first)
        #expect(persistedTask.comments.map(\.body) == ["Updated first comment"])
        #expect(persistedTask.notes == nil)
        #expect(!store.state.isEditSheetPresented)
    }
}
