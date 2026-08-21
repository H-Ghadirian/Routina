import SwiftUI

struct TaskDetailExtrasSectionView: View {
    let imageData: Data?
    let voiceNote: RoutineVoiceNote?
    let attachments: [AttachmentItem]
    let taskDescription: String?
    let notes: String?
    let links: [RoutineTaskResolvedLink]
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

            if let taskDescription {
                formattedTextBlock(title: "Description", text: taskDescription)
            }

            if let notes {
                formattedTextBlock(title: "Notes", text: notes)
            }

            ForEach(links) { link in
                Link(destination: link.url) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text(link.text)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .taskDetailCopyableText(link.url.absoluteString)
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

    private func formattedTextBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            RoutinaFormattedText(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .taskDetailCopyableText(text)
        }
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

struct TaskDetailAddDetailChooserView: View {
    let actions: [TaskDetailOptionalAction]
    var showsHeader = true
    let onSelect: (TaskDetailOptionalAction) -> Void
    @State private var hoveredActionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Add a detail")
                        .font(.headline)

                    Spacer(minLength: 12)

                    Text(optionCountText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(actions) { action in
                        actionButton(action)
                    }
                }
                .padding(6)
            }
        }
    }

    private var optionCountText: String {
        actions.count == 1 ? "1 available" : "\(actions.count) available"
    }

    private func actionButton(_ action: TaskDetailOptionalAction) -> some View {
        Button {
            onSelect(action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: action.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)

                Text(action.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    hoveredActionID == action.id
                        ? Color.accentColor.opacity(0.12)
                        : Color.secondary.opacity(0.001)
                )
        }
        .onHover { isHovered in
            hoveredActionID = isHovered ? action.id : nil
        }
    }
}

struct TaskDetailOptionalAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let perform: () -> Void

    init(
        id: String? = nil,
        title: String,
        systemImage: String,
        perform: @escaping () -> Void
    ) {
        self.id = id ?? title
        self.title = title
        self.systemImage = systemImage
        self.perform = perform
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
