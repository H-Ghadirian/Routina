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

    private var displayedComments: [RoutineTaskComment] {
        RoutineTaskCommentPresentation.newestFirst(comments)
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Comments")
                    .font(.headline)

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
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: RoutineTaskComment) -> some View {
        if editingCommentID == comment.id {
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
                Text(comment.body)
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

    private func commentEditor(
        draft: String,
        placeholder: String,
        minHeight: CGFloat,
        accessibilityIdentifier: String,
        onChanged: @escaping (String) -> Void
    ) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: draftBinding(draft: draft, onChanged: onChanged))
                .font(.subheadline)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                )
                .accessibilityIdentifier(accessibilityIdentifier)

            if draft.isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
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
}
