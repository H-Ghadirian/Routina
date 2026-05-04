import SwiftUI

struct AddRoutineImageAttachmentContent<ImagePreview: View, PhotoPickerButton: View, ImportButton: View, DropHint: View>: View {
    let imageData: Data?
    let onRemove: () -> Void
    let imagePreview: (Data) -> ImagePreview
    let photoPickerButton: (String) -> PhotoPickerButton
    let importButton: () -> ImportButton
    let dropHint: () -> DropHint

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageData {
                imagePreview(imageData)
                    .frame(height: 180)
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
                photoPickerButton(imagePickerLabel)

                importButton()

                if imageData != nil {
                    Button("Remove", action: onRemove)
                        .buttonStyle(.bordered)
                }
            }

            Text("Images are resized and compressed before saving to keep iCloud usage low.")
                .font(.caption)
                .foregroundStyle(.secondary)

            dropHint()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }

    private var imagePickerLabel: String {
        imageData == nil ? "Choose Image" : "Replace Image"
    }
}
