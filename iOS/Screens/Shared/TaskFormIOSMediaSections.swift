import Foundation
import PhotosUI
import SwiftUI

struct TaskFormIOSImageContent: View {
    let model: TaskFormModel
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let imagePickerLabel = model.imageData == nil ? "Choose Image" : "Replace Image"
        VStack(alignment: .leading, spacing: 10) {
            if let imageData = model.imageData {
                TaskImageView(data: imageData)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
            } else {
                Label("No image selected", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(imagePickerLabel, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                if model.imageData != nil {
                    Button("Remove") {
                        selectedPhotoItem = nil
                        model.onRemoveImage()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Images are resized and compressed before saving to reduce storage use.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}

struct TaskFormIOSAttachmentContent: View {
    let model: TaskFormModel
    let onAddFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.attachments.isEmpty {
                Label("No files attached", systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.attachments) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                        Text(item.fileName)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            model.onRemoveAttachment(item.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Button {
                onAddFile()
            } label: {
                Label("Add File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)

            Text("Attach any file up to 20 MB (PDF, document, spreadsheet, etc.).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}
