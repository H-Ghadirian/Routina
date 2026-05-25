import SwiftUI

struct TaskDetailExtrasSectionView: View {
    let imageData: Data?
    let voiceNote: RoutineVoiceNote?
    let attachments: [AttachmentItem]
    let notes: String?
    let linkURL: URL?
    let linkText: String?
    let background: Color
    let stroke: Color
    var onOpenImage: ((Data) -> Void)? = nil
    let onSaveAttachment: (AttachmentItem) -> Void
    let onOpenAttachment: (AttachmentItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            if let imageData {
                imageContent(for: imageData)
            }

            if let voiceNote {
                TaskVoiceNotePlaybackControl(voiceNote: voiceNote)
            }

            ForEach(attachments) { item in
                TaskDetailAttachmentRow(
                    item: item,
                    onSave: { onSaveAttachment(item) },
                    onOpen: { onOpenAttachment(item) }
                )
            }

            if let notes {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .taskDetailCopyableText(notes)
            }

            if let linkURL {
                let displayText = linkText ?? linkURL.absoluteString
                Link(destination: linkURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text(displayText)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .taskDetailCopyableText(displayText)
            }
        }
        .padding(12)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func imageContent(for imageData: Data) -> some View {
        if let onOpenImage {
            Button {
                onOpenImage(imageData)
            } label: {
                taskImage(data: imageData)
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .help("Open image in another app")
        } else {
            taskImage(data: imageData)
        }
    }

    private func taskImage(data: Data) -> some View {
        TaskImageView(data: data)
            .frame(maxWidth: .infinity, maxHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TaskDetailOptionalActionsSectionView: View {
    let showsCommentAction: Bool
    let showsLinkedTaskAction: Bool
    let showsDetailsAction: Bool
    let background: Color
    let stroke: Color
    let onAddComment: () -> Void
    let onAddLinkedTask: () -> Void
    let onEditDetails: () -> Void

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add More")
                    .font(.headline)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        actionButtons
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if showsCommentAction {
            actionButton(
                title: "Comment",
                systemImage: "text.bubble",
                action: onAddComment
            )
        }

        if showsLinkedTaskAction {
            actionButton(
                title: "Linked Task",
                systemImage: "link.badge.plus",
                action: onAddLinkedTask
            )
        }

        if showsDetailsAction {
            actionButton(
                title: "Details",
                systemImage: "square.and.pencil",
                action: onEditDetails
            )
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
    }
}

private struct TaskDetailAttachmentRow: View {
    let item: AttachmentItem
    let onSave: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.accentColor)
            Text(item.fileName)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                onSave()
            } label: {
                Image(systemName: "arrow.down.doc")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Save to Files")
            Button {
                onOpen()
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open with...")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
