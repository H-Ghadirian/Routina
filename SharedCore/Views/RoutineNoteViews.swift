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

    let note: RoutineNote?
    private let initialAttachments: [RoutineNoteAttachment]

    @State private var title: String
    @State private var bodyText: String
    @State private var tags: [String]
    @State private var tagDraft = ""
    @State private var imageData: Data?
    @State private var voiceNote: RoutineVoiceNote?
    @State private var attachments: [AttachmentItem]
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isImageImporterPresented = false
    @State private var isFileImporterPresented = false
    @State private var errorText: String?

    let onCancel: (() -> Void)?
    let onSaved: ((UUID) -> Void)?

    init(
        note: RoutineNote? = nil,
        attachments: [RoutineNoteAttachment] = [],
        onCancel: (() -> Void)? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.note = note
        self.initialAttachments = attachments
        self.onCancel = onCancel
        self.onSaved = onSaved
        let draft = note == nil ? RoutineNoteDraftSnapshot.load() : nil
        let storedAttachments = attachments.sorted { $0.createdAt < $1.createdAt }.map {
            AttachmentItem(id: $0.id, fileName: $0.fileName, data: $0.data)
        }
        _title = State(initialValue: note?.title ?? draft?.title ?? "")
        _bodyText = State(initialValue: note?.body ?? draft?.bodyText ?? "")
        _tags = State(initialValue: note?.tags ?? draft?.tags ?? [])
        _tagDraft = State(initialValue: draft?.tagDraft ?? "")
        _imageData = State(initialValue: note?.imageData ?? draft?.imageData)
        _voiceNote = State(initialValue: note?.voiceNote ?? draft?.voiceNote)
        _attachments = State(initialValue: note == nil ? draft?.attachments ?? [] : storedAttachments)
    }

    var body: some View {
        NavigationStack {
            editorContent
            .navigationTitle(editorTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
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
            #endif
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
        .onChange(of: currentDraftSnapshot) { _, snapshot in
            guard note == nil else { return }
            snapshot.persist()
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 620)
        #endif
    }

    private var editorTitle: String {
        note == nil ? "New Note" : "Edit Note"
    }

    @ViewBuilder
    private var editorContent: some View {
        #if os(macOS)
        macEditorContent
        #else
        formEditorContent
        #endif
    }

    private var formEditorContent: some View {
        Form {
            Section("Note") {
                TextField("Title", text: $title)
                RoutinaFormattedTextEditor(
                    text: $bodyText,
                    placeholder: "Write a note",
                    minHeight: 120
                )
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
    }

    #if os(macOS)
    private var macEditorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                macHeader

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 18) {
                            macNoteCard
                            macTagsCard
                        }
                        .frame(minWidth: 520, maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: 18) {
                            macImageCard
                            macVoiceCard
                            macFilesCard
                        }
                        .frame(width: 320, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        macNoteCard
                        macTagsCard
                        macImageCard
                        macVoiceCard
                        macFilesCard
                    }
                }

                if let errorText {
                    macErrorBanner(errorText)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 980, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var macHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                Image(systemName: "note.text")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 48, height: 48)

            Text(editorTitle)
                .font(.largeTitle.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 16)

            Button("Cancel") {
                cancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button {
                save()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasContent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var macNoteCard: some View {
        RoutineNoteEditorCard(title: "Note", systemImage: "text.alignleft") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("", text: $title, prompt: Text("Untitled note"))
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(macInputBackground)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Write a note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    RoutinaFormattedTextEditor(
                        text: $bodyText,
                        placeholder: "Write a note",
                        minHeight: 260,
                        backgroundColor: .secondary.opacity(0.08),
                        strokeColor: .secondary.opacity(0.18),
                        cornerRadius: 8
                    )
                }
            }
        }
    }

    private var macTagsCard: some View {
        RoutineNoteEditorCard(title: "Tags", systemImage: "tag") {
            VStack(alignment: .leading, spacing: 12) {
                macTagComposer
                selectedTagsContent
                existingTagsContent
            }
        }
    }

    private var macImageCard: some View {
        RoutineNoteEditorCard(title: "Image", systemImage: "photo") {
            imageSection
        }
    }

    private var macVoiceCard: some View {
        RoutineNoteEditorCard(title: "Voice", systemImage: "mic") {
            TaskVoiceNoteRecorderControl(voiceNote: voiceNote, onVoiceNoteChanged: {
                voiceNote = $0
            })
        }
    }

    private var macFilesCard: some View {
        RoutineNoteEditorCard(title: "Files", systemImage: "paperclip") {
            filesSection
        }
    }

    private var macTagComposer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                TextField("", text: $tagDraft, prompt: Text("health, focus, morning"))
                    .textFieldStyle(.plain)
                    .onSubmit(addTagDraft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 96)
                    .background(macInputBackground)

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
                    .padding(.trailing, 6)
                    .accessibilityLabel("Complete tag \(suggestion)")
                }
            }

            Button {
                addTagDraft()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(RoutineTag.parseDraft(tagDraft).isEmpty)
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

    private var hasContent: Bool {
        RoutineNote.cleanedText(title) != nil
            || RoutineNote.cleanedText(bodyText) != nil
            || imageData?.isEmpty == false
            || voiceNote != nil
            || !attachments.isEmpty
    }

    private var currentDraftSnapshot: RoutineNoteDraftSnapshot {
        RoutineNoteDraftSnapshot(
            title: title,
            bodyText: bodyText,
            tags: tags,
            tagDraft: tagDraft,
            imageData: imageData,
            voiceNote: voiceNote,
            attachments: attachments
        )
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
        if note == nil {
            CreationDraftPersistence.clear(.note)
        }
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

            existingTagsContent
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

    @ViewBuilder
    private var existingTagsContent: some View {
        if !availableUnselectedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(availableUnselectedTags, id: \.self) { tag in
                        Button {
                            tags = RoutineTag.appending(tag, to: tags, availableTags: availableTags)
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
        let target = note ?? RoutineNote(createdAt: now, updatedAt: now)
        target.title = RoutineNote.cleanedText(title)
        target.body = RoutineNote.cleanedText(bodyText)
        target.tags = tags
        target.imageData = imageData?.isEmpty == false ? imageData : nil
        target.voiceNote = voiceNote
        if target.createdAt == nil {
            target.createdAt = now
        }
        target.updatedAt = now

        if note == nil {
            modelContext.insert(target)
        }
        syncAttachments(for: target, savedAt: now)

        do {
            try modelContext.save()
            if note == nil {
                CreationDraftPersistence.clear(.note)
            }
            onSaved?(target.id)
            dismiss()
        } catch {
            errorText = "Could not save the note."
        }
    }

    private func syncAttachments(for note: RoutineNote, savedAt now: Date) {
        let existingAttachments = initialAttachments.filter { $0.noteID == note.id }
        let existingByID = Dictionary(uniqueKeysWithValues: existingAttachments.map { ($0.id, $0) })
        let draftIDs = Set(attachments.map(\.id))

        for existingAttachment in existingAttachments where !draftIDs.contains(existingAttachment.id) {
            modelContext.delete(existingAttachment)
        }

        for attachment in attachments {
            if let existingAttachment = existingByID[attachment.id] {
                existingAttachment.noteID = note.id
                existingAttachment.fileName = RoutineNoteAttachment.cleanedFileName(attachment.fileName)
                existingAttachment.data = attachment.data
            } else {
                modelContext.insert(RoutineNoteAttachment(
                    id: attachment.id,
                    noteID: note.id,
                    fileName: attachment.fileName,
                    data: attachment.data,
                    createdAt: now
                ))
            }
        }
    }

    private func addTagDraft() {
        guard !RoutineTag.parseDraft(tagDraft).isEmpty else { return }
        tags = RoutineTag.appending(tagDraft, to: tags, availableTags: availableTags)
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

private struct RoutineNoteEditorCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .routinaGlassPanel(cornerRadius: 14, tint: .secondary, tintOpacity: 0.06)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }
}

struct RoutinaFormattedTextEditor: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 120
    var font: Font = .body
    var backgroundColor: Color = .secondary.opacity(0.08)
    var strokeColor: Color = .secondary.opacity(0.16)
    var cornerRadius: CGFloat = 10
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(font)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .padding(8)
                    .background(background)
                    .accessibilityIdentifier(accessibilityIdentifier ?? "")

                if text.isEmpty {
                    Text(placeholder)
                        .font(font)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            RoutinaTextFormattingToolbar(text: $text)
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }
}

struct RoutinaTextFormattingToolbar: View {
    @Binding var text: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(RoutinaTextFormattingCommand.allCases) { command in
                    Button {
                        text = command.applying(to: text)
                    } label: {
                        Image(systemName: command.systemImage)
                            .font(.caption.weight(.semibold))
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(command.title)
                    .accessibilityLabel(command.title)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

enum RoutinaTextFormattingCommand: String, CaseIterable, Identifiable {
    case heading
    case bold
    case italic
    case bulletList
    case checklist
    case quote
    case code
    case link

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heading: return "Heading"
        case .bold: return "Bold"
        case .italic: return "Italic"
        case .bulletList: return "Bullet List"
        case .checklist: return "Checklist"
        case .quote: return "Quote"
        case .code: return "Code"
        case .link: return "Link"
        }
    }

    var systemImage: String {
        switch self {
        case .heading: return "textformat.size"
        case .bold: return "bold"
        case .italic: return "italic"
        case .bulletList: return "list.bullet"
        case .checklist: return "checklist"
        case .quote: return "quote.opening"
        case .code: return "curlybraces"
        case .link: return "link"
        }
    }

    func applying(to text: String) -> String {
        switch self {
        case .heading:
            return appendingBlock("## Heading", to: text)
        case .bold:
            return appendingInline("**bold text**", to: text)
        case .italic:
            return appendingInline("_italic text_", to: text)
        case .bulletList:
            return appendingBlock("- List item", to: text)
        case .checklist:
            return appendingBlock("- [ ] Checklist item", to: text)
        case .quote:
            return appendingBlock("> Quote", to: text)
        case .code:
            return appendingInline("`code`", to: text)
        case .link:
            return appendingInline("[link text](https://example.com)", to: text)
        }
    }

    private func appendingInline(_ snippet: String, to text: String) -> String {
        guard !text.isEmpty else { return snippet }
        if text.last?.isWhitespace == true {
            return text + snippet
        }
        return text + " " + snippet
    }

    private func appendingBlock(_ snippet: String, to text: String) -> String {
        guard !text.isEmpty else { return snippet }
        if text.hasSuffix("\n\n") {
            return text + snippet
        }
        if text.hasSuffix("\n") {
            return text + "\n" + snippet
        }
        return text + "\n\n" + snippet
    }
}

struct RoutinaFormattedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(Self.attributedText(from: text))
    }

    static func attributedText(from text: String) -> AttributedString {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedText.components(separatedBy: "\n")
        guard lines.count > 1 else {
            return markdownAttributedText(from: normalizedText)
        }

        return lines.enumerated().reduce(into: AttributedString()) { result, entry in
            if entry.offset > 0 {
                result += AttributedString("\n")
            }
            guard !entry.element.isEmpty else { return }
            result += markdownAttributedText(from: entry.element)
        }
    }

    private static func markdownAttributedText(from text: String) -> AttributedString {
        (
            try? AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            )
        ) ?? AttributedString(text)
    }
}

struct RoutineNoteDetailView: View {
    let note: RoutineNote
    let attachments: [RoutineNoteAttachment]
    let onEdit: (() -> Void)?
    @State private var isEditing = false

    init(
        note: RoutineNote,
        attachments: [RoutineNoteAttachment],
        onEdit: (() -> Void)? = nil
    ) {
        self.note = note
        self.attachments = attachments
        self.onEdit = onEdit
    }

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
                    RoutinaFormattedText(body)
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
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let onEdit {
                        onEdit()
                    } else {
                        isEditing = true
                    }
                } label: {
                    Label("Edit Note", systemImage: "pencil")
                }

                RoutinaDeepLinkShareMenu(
                    title: note.displayTitle,
                    deepLink: .note(note.id)
                )
            }
        }
        .sheet(isPresented: $isEditing) {
            RoutineNoteEditorView(note: note, attachments: attachments)
        }
        .onChange(of: note.id) { _, _ in
            isEditing = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.displayTitle)
                .font(.largeTitle.weight(.semibold))
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 2) {
                Text((note.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened))

                if let editedDateText {
                    Text(editedDateText)
                }
            }
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

    private var editedDateText: String? {
        guard let updatedAt = note.updatedAt else { return nil }
        if let createdAt = note.createdAt,
           updatedAt.timeIntervalSince(createdAt) < 1 {
            return nil
        }
        return RoutineNoteDateFormatting.editedText(for: updatedAt)
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

enum RoutineNoteDateFormatting {
    static func editedText(for date: Date) -> String {
        "Edited \(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "en_GB"))))"
    }
}

private func byteCountText(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
}
