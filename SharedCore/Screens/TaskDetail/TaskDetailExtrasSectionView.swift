import SwiftUI

struct TaskDetailExtrasSectionView: View {
    let imageData: Data?
    let voiceNote: RoutineVoiceNote?
    let attachments: [AttachmentItem]
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

            if let notes {
                RoutinaFormattedText(notes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .taskDetailCopyableText(notes)
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
                .taskDetailCopyableText(link.text)
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
    let actions: [TaskDetailOptionalAction]
    let background: Color
    let stroke: Color

    @State private var isExpanded = false

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                TaskDetailCollapsibleSectionHeaderView(
                    title: "Add more details",
                    count: actions.count,
                    isExpanded: isExpanded,
                    onToggle: { isExpanded.toggle() }
                )

                if isExpanded {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 124), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        actionButtons
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        ForEach(actions) { action in
            actionButton(action)
        }
    }

    private func actionButton(_ action: TaskDetailOptionalAction) -> some View {
        Button(action: action.perform) {
            Label(action.title, systemImage: action.systemImage)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
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
