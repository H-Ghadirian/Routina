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
    func commentStorageAndDisplayPreserveLineBreaks() {
        let body = "First line\nSecond line\n\nFourth line"
        let comments = [
            RoutineTaskComment(body: body, createdAt: makeDate("2026-04-02T08:15:00Z"))
        ]

        let restoredComment = RoutineTaskCommentStorage.deserialize(
            RoutineTaskCommentStorage.serialize(comments)
        ).first
        let displayedBody = String(RoutinaFormattedText.attributedText(from: body).characters)

        #expect(restoredComment?.body == body)
        #expect(displayedBody == body)
    }

    @Test
    func commentPresentationShowsNewestCreatedCommentFirst() {
        let olderDate = makeDate("2026-04-02T08:15:00Z")
        let newerDate = makeDate("2026-04-02T09:30:00Z")
        let comments = [
            RoutineTaskComment(body: "Older", createdAt: olderDate),
            RoutineTaskComment(body: "Newer", createdAt: newerDate)
        ]

        #expect(RoutineTaskCommentPresentation.newestFirst(comments).map(\.body) == ["Newer", "Older"])
    }

    @Test
    func commentPresentationShowsLaterInsertionFirstWhenDatesMatch() {
        let createdAt = makeDate("2026-04-02T08:15:00Z")
        let comments = [
            RoutineTaskComment(body: "First", createdAt: createdAt),
            RoutineTaskComment(body: "Second", createdAt: createdAt)
        ]

        #expect(RoutineTaskCommentPresentation.newestFirst(comments).map(\.body) == ["Second", "First"])
    }

    @Test
    func commentPresentationShowsOnlyThreeNewestCommentsByDefault() {
        let comments = [
            RoutineTaskComment(body: "First", createdAt: makeDate("2026-04-02T08:00:00Z")),
            RoutineTaskComment(body: "Second", createdAt: makeDate("2026-04-02T08:05:00Z")),
            RoutineTaskComment(body: "Third", createdAt: makeDate("2026-04-02T08:10:00Z")),
            RoutineTaskComment(body: "Fourth", createdAt: makeDate("2026-04-02T08:15:00Z")),
            RoutineTaskComment(body: "Fifth", createdAt: makeDate("2026-04-02T08:20:00Z"))
        ]

        let visibleComments = RoutineTaskCommentPresentation.visibleComments(comments, showAll: false)

        #expect(visibleComments.map(\.body) == ["Fifth", "Fourth", "Third"])
    }

    @Test
    func commentPresentationShowsAllCommentsWhenExpanded() {
        let comments = [
            RoutineTaskComment(body: "First", createdAt: makeDate("2026-04-02T08:00:00Z")),
            RoutineTaskComment(body: "Second", createdAt: makeDate("2026-04-02T08:05:00Z")),
            RoutineTaskComment(body: "Third", createdAt: makeDate("2026-04-02T08:10:00Z")),
            RoutineTaskComment(body: "Fourth", createdAt: makeDate("2026-04-02T08:15:00Z"))
        ]

        let visibleComments = RoutineTaskCommentPresentation.visibleComments(comments, showAll: true)

        #expect(visibleComments.map(\.body) == ["Fourth", "Third", "Second", "First"])
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

    @Test
    func detailChecklist_canAddItemWithoutOpeningEditSheet() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-02T08:15:00Z")
        let existingItem = RoutineChecklistItem(
            title: "Milk",
            intervalDays: 3,
            createdAt: makeDate("2026-04-01T08:15:00Z")
        )
        let task = makeTask(
            in: context,
            name: "Groceries",
            interval: 1,
            lastDone: nil,
            emoji: "G",
            checklistItems: [existingItem]
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task.detachedCopy()
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editChecklistItemDraftTitleChanged(" Bread ")) {
            $0.editChecklistItemDraftTitle = " Bread "
        }
        await store.send(.editChecklistItemDraftIntervalChanged(7)) {
            $0.editChecklistItemDraftInterval = 7
        }
        await store.send(.detailAddChecklistItemTapped)

        #expect(store.state.editChecklistItemDraftTitle.isEmpty)
        #expect(store.state.editChecklistItemDraftInterval == 3)
        #expect(store.state.task.checklistItems.map(\.title) == ["Milk", "Bread"])
        #expect(store.state.task.checklistItems.last?.intervalDays == 7)
        #expect(store.state.task.checklistItems.last?.createdAt == now)
        #expect(!store.state.isEditSheetPresented)

        let taskID = task.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { task in
                task.id == taskID
            }
        )
        let persistedTask = try #require(context.fetch(descriptor).first)
        #expect(persistedTask.checklistItems.map(\.title) == ["Milk", "Bread"])
        #expect(persistedTask.checklistItems.last?.intervalDays == 7)
    }
}
