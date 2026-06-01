import SwiftUI

struct TaskDetailCommentsSectionView: View {
    let comments: [RoutineTaskComment]
    let newCommentDraft: String
    let canAddComment: Bool
    let editingCommentID: UUID?
    let editingCommentDraft: String
    let canSaveEditedComment: Bool
    let background: Color
    let stroke: Color
    let onNewCommentDraftChanged: (String) -> Void
    let onAddComment: () -> Void
    let onEditComment: (UUID) -> Void
    let onEditCommentDraftChanged: (String) -> Void
    let onCancelEditComment: () -> Void
    let onSaveEditComment: (UUID) -> Void
    let onDeleteComment: (UUID) -> Void

    @State private var isExpanded = true
    @State private var isShowingAllComments = false
    @State private var hiddenCommentIDs: Set<UUID> = []

    private static let collapsedCommentLimit = 3

    private var displayedComments: [RoutineTaskComment] {
        RoutineTaskCommentPresentation.visibleComments(
            comments,
            showAll: isShowingAllComments,
            limit: Self.collapsedCommentLimit
        )
    }

    private var sortedComments: [RoutineTaskComment] {
        RoutineTaskCommentPresentation.newestFirst(comments)
    }

    private var hiddenOlderCommentCount: Int {
        max(0, sortedComments.count - displayedComments.count)
    }

    private var shouldShowMoreCommentsControl: Bool {
        !isShowingAllComments && hiddenOlderCommentCount > 0
    }

    private var currentCommentIDs: Set<UUID> {
        Set(comments.map(\.id))
    }

    private var currentHiddenCommentIDs: Set<UUID> {
        hiddenCommentIDs.intersection(currentCommentIDs)
    }

    private var hiddenCommentCount: Int {
        currentHiddenCommentIDs.count
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                TaskDetailCollapsibleSectionHeaderView(
                    title: "Comments",
                    count: comments.count,
                    isExpanded: isExpanded,
                    onToggle: { isExpanded.toggle() }
                )

                if isExpanded {
                    expandedContent
                }
            }
        }
        .onChange(of: comments.map(\.id)) { _, commentIDs in
            hiddenCommentIDs.formIntersection(Set(commentIDs))
            if commentIDs.count <= Self.collapsedCommentLimit {
                isShowingAllComments = false
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        commentEditor(
            draft: newCommentDraft,
            placeholder: "Add a comment...",
            minHeight: 86,
            accessibilityIdentifier: "task-detail-new-comment-editor",
            onChanged: onNewCommentDraftChanged
        )

        HStack {
            Spacer()

            Button {
                onAddComment()
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddComment)
        }

        if hiddenCommentCount > 0 {
            hiddenCommentsControl
        }

        if comments.isEmpty {
            Text("No comments yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(displayedComments.enumerated()), id: \.element.id) { index, comment in
                    commentRow(comment)

                    if index < displayedComments.count - 1 {
                        Divider()
                            .padding(.vertical, 10)
                    }
                }

                if shouldShowMoreCommentsControl {
                    Divider()
                        .padding(.vertical, 10)

                    showMoreCommentsButton
                }
            }
        }
    }

    private var showMoreCommentsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isShowingAllComments = true
            }
        } label: {
            Label("Show more", systemImage: "chevron.down.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint("Shows \(hiddenOlderCommentCount) older comments")
    }

    private var hiddenCommentsControl: some View {
        HStack(spacing: 8) {
            Label("\(hiddenCommentCount) hidden", systemImage: "eye.slash")
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    hiddenCommentIDs.removeAll()
                    isExpanded = true
                }
            } label: {
                Label("Show All", systemImage: "eye")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.07)
    }

    @ViewBuilder
    private func commentRow(_ comment: RoutineTaskComment) -> some View {
        if currentHiddenCommentIDs.contains(comment.id), editingCommentID != comment.id {
            hiddenCommentRow(comment)
        } else if editingCommentID == comment.id {
            VStack(alignment: .leading, spacing: 8) {
                commentEditor(
                    draft: editingCommentDraft,
                    placeholder: "Edit comment...",
                    minHeight: 74,
                    accessibilityIdentifier: "task-detail-edit-comment-editor",
                    onChanged: onEditCommentDraftChanged
                )

                HStack {
                    Spacer()

                    Button {
                        onCancelEditComment()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }

                    Button {
                        onSaveEditComment(comment.id)
                    } label: {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSaveEditedComment)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                RoutinaFormattedText(comment.body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .taskDetailCopyableText(comment.body)

                VStack(alignment: .leading, spacing: 6) {
                    Text(metadataText(for: comment))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Spacer(minLength: 0)

                        Button {
                            hideComment(comment.id)
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
                        }
                        .buttonStyle(.plain)

                        Button {
                            onEditComment(comment.id)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            onDeleteComment(comment.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func hiddenCommentRow(_ comment: RoutineTaskComment) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text("Hidden comment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(metadataText(for: comment))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showComment(comment.id)
            } label: {
                Label("Show", systemImage: "eye")
            }
            .buttonStyle(.plain)
        }
    }

    private func commentEditor(
        draft: String,
        placeholder: String,
        minHeight: CGFloat,
        accessibilityIdentifier: String,
        onChanged: @escaping (String) -> Void
    ) -> some View {
        RoutinaFormattedTextEditor(
            text: draftBinding(draft: draft, onChanged: onChanged),
            placeholder: placeholder,
            minHeight: minHeight,
            font: .subheadline,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    private func draftBinding(
        draft: String,
        onChanged: @escaping (String) -> Void
    ) -> Binding<String> {
        Binding(
            get: { draft },
            set: { newValue in
                onChanged(newValue)
            }
        )
    }

    private func metadataText(for comment: RoutineTaskComment) -> String {
        let createdText = "Added \(formattedTimestamp(comment.createdAt))"
        guard let updatedAt = comment.updatedAt else {
            return createdText
        }
        let updatedText = "Edited \(formattedTimestamp(updatedAt))"
        return "\(createdText) · \(updatedText)"
    }

    private func formattedTimestamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func hideComment(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            _ = hiddenCommentIDs.insert(id)
        }
    }

    private func showComment(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            _ = hiddenCommentIDs.remove(id)
        }
    }
}

enum RoutineTaskCommentPresentation {
    static func newestFirst(_ comments: [RoutineTaskComment]) -> [RoutineTaskComment] {
        comments
            .enumerated()
            .sorted { left, right in
                if left.element.createdAt != right.element.createdAt {
                    return left.element.createdAt > right.element.createdAt
                }

                return left.offset > right.offset
            }
            .map(\.element)
    }

    static func visibleComments(
        _ comments: [RoutineTaskComment],
        showAll: Bool,
        limit: Int = 3
    ) -> [RoutineTaskComment] {
        let sortedComments = newestFirst(comments)
        guard !showAll, limit > 0 else {
            return sortedComments
        }

        return Array(sortedComments.prefix(limit))
    }
}
