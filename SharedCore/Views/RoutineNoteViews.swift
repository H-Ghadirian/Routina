import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RoutineNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    @Query private var goals: [RoutineGoal]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) private var existingNotes: [RoutineNote]

    @State private var title = ""
    @State private var bodyText = ""
    @State private var tags: [String] = []
    @State private var tagDraft = ""
    @State private var imageData: Data?
    @State private var voiceNote: RoutineVoiceNote?
    @State private var attachments: [AttachmentItem] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageImporterPresented = false
    @State private var isFileImporterPresented = false
    @State private var errorText: String?

    let onCancel: (() -> Void)?
    let onSaved: (() -> Void)?

    init(
        onCancel: (() -> Void)? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.onCancel = onCancel
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Title", text: $title)
                    TextField("Write a note", text: $bodyText, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                }

                Section("Tags") {
                    tagsSection
                }

                Section("Image") {
                    imageSection
                }

                Section("Voice") {
                    TaskVoiceNoteRecorderControl(voiceNote: voiceNote, onVoiceNoteChanged: {
                        voiceNote = $0
                    })
                }

                Section("Files") {
                    filesSection
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!hasContent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
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
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 620)
        #endif
    }

    private var hasContent: Bool {
        RoutineNote.cleanedText(title) != nil
            || RoutineNote.cleanedText(bodyText) != nil
            || imageData?.isEmpty == false
            || voiceNote != nil
            || !attachments.isEmpty
    }

    private var availableTags: [String] {
        RoutineTag.allTags(
            from: tasks.map(\.tags) + goals.map(\.tags) + existingNotes.map(\.tags)
        )
    }

    private var availableUnselectedTags: [String] {
        availableTags.filter { !RoutineTag.contains($0, in: tags) }
    }

    private var tagAutocompleteSuggestion: String? {
        RoutineTag.autocompleteSuggestion(
            for: tagDraft,
            availableTags: availableTags,
            selectedTags: tags
        )
    }

    private func cancel() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("health, focus, morning", text: $tagDraft)
                        .onSubmit(addTagDraft)
                        .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 88)

                    if let suggestion = tagAutocompleteSuggestion {
                        Button {
                            acceptTagAutocompleteSuggestion()
                        } label: {
                            Text("#\(suggestion)")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .routinaGlassPill(tint: .secondary, tintOpacity: 0.12, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete tag \(suggestion)")
                    }
                }

                Button {
                    addTagDraft()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(RoutineTag.parseDraft(tagDraft).isEmpty)
            }

            selectedTagsContent

            if !availableUnselectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Existing tags")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(availableUnselectedTags, id: \.self) { tag in
                            Button {
                                tags = RoutineTag.appending(tag, to: tags)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                        .font(.caption)
                                    Text("#\(tag)")
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .routinaGlassPill(tint: .secondary, tintOpacity: 0.10, interactive: true)
                                .overlay {
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                            .accessibilityLabel("Add tag \(tag)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var selectedTagsContent: some View {
        if tags.isEmpty {
            Text("No tags selected")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        tags = RoutineTag.removing(tag, from: tags)
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.14, interactive: true)
                        .overlay {
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var imageSection: some View {
        let photoPickerTitle = imageData == nil ? "Choose Image" : "Replace Image"
        return VStack(alignment: .leading, spacing: 10) {
            if let imageData, !imageData.isEmpty {
                RoutineNoteImagePreview(data: imageData, contentMode: .fit)
                    .frame(maxWidth: .infinity)
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
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(photoPickerTitle, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button(imageData == nil ? "Browse" : "Browse Another File") {
                    isImageImporterPresented = true
                }
                .buttonStyle(.bordered)

                if imageData != nil {
                    Button("Remove") {
                        selectedPhotoItem = nil
                        imageData = nil
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Images are resized and compressed before saving.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if attachments.isEmpty {
                Label("No files attached", systemImage: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attachments) { attachment in
                    HStack(spacing: 10) {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.fileName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(byteCountText(attachment.data.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            attachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove file")
                    }
                }
            }

            Button {
                isFileImporterPresented = true
            } label: {
                Label("Add File", systemImage: "paperclip")
            }
            .buttonStyle(.bordered)

            Text("Files up to 20 MB are saved with the note.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func save() {
        guard hasContent else { return }
        let now = Date()
        let note = RoutineNote(
            title: title,
            body: bodyText,
            tags: tags,
            imageData: imageData,
            voiceNoteData: voiceNote?.data,
            voiceNoteDurationSeconds: voiceNote?.durationSeconds,
            voiceNoteCreatedAt: voiceNote?.createdAt,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(note)
        for attachment in attachments {
            modelContext.insert(
                RoutineNoteAttachment(
                    id: attachment.id,
                    noteID: note.id,
                    fileName: attachment.fileName,
                    data: attachment.data,
                    createdAt: now
                )
            )
        }

        do {
            try modelContext.save()
            onSaved?()
            dismiss()
        } catch {
            errorText = "Could not save the note."
        }
    }

    private func addTagDraft() {
        guard !RoutineTag.parseDraft(tagDraft).isEmpty else { return }
        tags = RoutineTag.appending(tagDraft, to: tags)
        tagDraft = ""
    }

    private func acceptTagAutocompleteSuggestion() {
        guard let suggestion = tagAutocompleteSuggestion else { return }
        tagDraft = RoutineTag.acceptingAutocompleteSuggestion(suggestion, in: tagDraft)
        addTagDraft()
    }

    private func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let compressedData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
            await MainActor.run {
                imageData = compressedData
                selectedPhotoItem = nil
            }
        }
    }

    private func handleImageImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        imageData = TaskImageProcessor.compressedImageData(fromFileAt: url)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        let maxSize = 20 * 1024 * 1024
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url), data.count <= maxSize else {
            errorText = "Files must be 20 MB or smaller."
            return
        }
        attachments.append(AttachmentItem(fileName: url.lastPathComponent, data: data))
        errorText = nil
    }
}

struct RoutineNoteDetailView: View {
    let note: RoutineNote
    let attachments: [RoutineNoteAttachment]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if !note.tags.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(note.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption.weight(.semibold))
                                Text(tag)
                                    .font(.footnote.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.secondary.opacity(0.16))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)
                            )
                            .fixedSize()
                        }
                    }
                }

                if let body = RoutineNote.cleanedText(note.body) {
                    Text(body)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let imageData = note.imageData, !imageData.isEmpty {
                    RoutineNoteImagePreview(data: imageData, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                }

                if let voiceNote = note.voiceNote {
                    TaskVoiceNotePlaybackControl(voiceNote: voiceNote, title: "Voice note")
                }

                if !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Files")
                            .font(.headline)

                        ForEach(attachments) { attachment in
                            HStack(spacing: 10) {
                                Image(systemName: "doc")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(attachment.fileName)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(byteCountText(attachment.data.count))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(note.displayTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RoutinaDeepLinkShareMenu(
                    title: note.displayTitle,
                    deepLink: .note(note.id)
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.displayTitle)
                .font(.largeTitle.weight(.semibold))
                .lineLimit(3)

            Text((note.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let mediaSummary = RoutineNoteMediaSummary.text(
                hasImage: note.hasImage,
                hasFileAttachment: !attachments.isEmpty,
                hasVoiceNote: note.hasVoiceNote
            ) {
                Label(mediaSummary, systemImage: "paperclip")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RoutineNoteImagePreview: View {
    let data: Data
    let contentMode: ContentMode

    var body: some View {
        if let image = previewImage {
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var previewImage: Image? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

private func byteCountText(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
}
