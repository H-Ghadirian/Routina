import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PlaceCheckInSessionEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PlaceCheckInSessionEditDraft
    @State private var errorText: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageImporterPresented = false

    let onSave: (PlaceCheckInSessionEditDraft) throws -> Void

    init(
        draft: PlaceCheckInSessionEditDraft,
        onSave: @escaping (PlaceCheckInSessionEditDraft) throws -> Void
    ) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        editorContent
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                loadPickedImage(from: newItem)
            }
            .fileImporter(
                isPresented: $isImageImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                handleImageImport(result)
            }
    }

    @ViewBuilder
    private var editorContent: some View {
        #if os(macOS)
            macEditorContent
                .frame(width: 640)
        #else
            NavigationStack {
                formEditorContent
                    .navigationTitle("Edit Check-In")
                    #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                save()
                            }
                            .disabled(validationMessage != nil)
                            .keyboardShortcut(.defaultAction)
                        }
                    }
            }
        #endif
    }

    private var formEditorContent: some View {
        let hasSelectedImage = hasImage
        let pickerLabel = imagePickerLabel(hasImage: hasSelectedImage)
        let importLabel = imageImportLabel(hasImage: hasSelectedImage)

        return Form {
            Section("Check-In") {
                TextField("Place name", text: $draft.placeName)

                TextField("Note", text: $draft.note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section("Image") {
                imagePreview(height: 180)

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(pickerLabel, systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)

                    Button(importLabel) {
                        isImageImporterPresented = true
                    }
                    .buttonStyle(.bordered)

                    if hasSelectedImage {
                        Button("Remove") {
                            selectedPhotoItem = nil
                            draft.imageData = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Section("Time") {
                DatePicker(
                    "Start",
                    selection: $draft.startedAt,
                    displayedComponents: [.date, .hourAndMinute]
                )

                if draft.canRemainActive {
                    Toggle("End active check-in", isOn: $draft.hasEndTime)
                }

                if draft.hasEndTime {
                    DatePicker(
                        "End",
                        selection: $draft.endedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    #if os(macOS)
        private var macEditorContent: some View {
            VStack(spacing: 0) {
                macHeader

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        macCheckInCard
                        macImageCard
                        macTimeCard

                        if let validationMessage {
                            macErrorBanner(validationMessage)
                        }

                        if let errorText {
                            macErrorBanner(errorText)
                        }
                    }
                    .padding(20)
                }

                Divider()

                macFooter
            }
            .frame(minHeight: 560)
        }

        private var macHeader: some View {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.16))
                    Image(systemName: "location.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                }
                .frame(width: 42, height: 42)

                Text("Edit Check-In")
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }

        private var macFooter: some View {
            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationMessage != nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }

        private var macCheckInCard: some View {
            PlaceCheckInDetailCard(title: "Check-In", systemImage: "mappin.and.ellipse") {
                VStack(alignment: .leading, spacing: 14) {
                    macField("Place name") {
                        TextField("", text: $draft.placeName, prompt: Text("Place name"))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(macInputBackground)
                    }

                    macField("Note") {
                        TextField("", text: $draft.note, prompt: Text("Add a note"), axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(4, reservesSpace: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(macInputBackground)
                    }
                }
            }
        }

        private var macImageCard: some View {
            let hasSelectedImage = hasImage
            let pickerLabel = imagePickerLabel(hasImage: hasSelectedImage)
            let importLabel = imageImportLabel(hasImage: hasSelectedImage)

            return PlaceCheckInDetailCard(title: "Image", systemImage: "photo") {
                HStack(alignment: .top, spacing: 14) {
                    imagePreview(height: 120)
                        .frame(width: 180, height: 120)

                    VStack(alignment: .leading, spacing: 10) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(pickerLabel, systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isImageImporterPresented = true
                        } label: {
                            Label(importLabel, systemImage: "folder")
                        }
                        .buttonStyle(.bordered)

                        if hasSelectedImage {
                            Button(role: .destructive) {
                                selectedPhotoItem = nil
                                draft.imageData = nil
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }

        private var macTimeCard: some View {
            PlaceCheckInDetailCard(title: "Time", systemImage: "clock") {
                VStack(alignment: .leading, spacing: 14) {
                    macField("Start") {
                        DatePicker(
                            "",
                            selection: $draft.startedAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                    }

                    if draft.canRemainActive {
                        Toggle("End active check-in", isOn: $draft.hasEndTime)
                            .toggleStyle(.checkbox)
                    }

                    if draft.hasEndTime {
                        macField("End") {
                            DatePicker(
                                "",
                                selection: $draft.endedAt,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                    }
                }
            }
        }

        private func macField<Content: View>(
            _ title: String,
            @ViewBuilder content: () -> Content
        ) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                content()
            }
        }

        private var macInputBackground: some View {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }

        private func macErrorBanner(_ message: String) -> some View {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
        }
    #endif

    private var hasImage: Bool {
        draft.imageData?.isEmpty == false
    }

    private func imagePickerLabel(hasImage: Bool) -> String {
        hasImage ? "Replace Image" : "Choose Image"
    }

    private func imageImportLabel(hasImage: Bool) -> String {
        hasImage ? "Browse Another File" : "Browse"
    }

    @ViewBuilder
    private func imagePreview(height: CGFloat) -> some View {
        if let imageData = draft.imageData, !imageData.isEmpty {
            PlaceCheckInImagePreview(data: imageData, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title3.weight(.semibold))
                Text("No image selected")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private var validationMessage: String? {
        if draft.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlaceCheckInSessionEditError.invalidPlaceName.localizedDescription
        }
        if draft.hasEndTime, draft.endedAt < draft.startedAt {
            return PlaceCheckInSessionEditError.invalidDateRange.localizedDescription
        }
        return nil
    }

    private func save() {
        guard validationMessage == nil else { return }

        do {
            try onSave(draft)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let compressedData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
            await MainActor.run {
                draft.imageData = compressedData
                selectedPhotoItem = nil
            }
        }
    }

    private func handleImageImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        draft.imageData = TaskImageProcessor.compressedImageData(fromFileAt: url)
    }
}
