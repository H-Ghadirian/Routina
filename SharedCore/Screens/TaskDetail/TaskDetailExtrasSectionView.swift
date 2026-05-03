import SwiftUI

struct TaskDetailExtrasSectionView: View {
    let imageData: Data?
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
            }

            if let linkURL {
                Link(destination: linkURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text(linkText ?? linkURL.absoluteString)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
