import SwiftUI

struct TaskFormLinksEditor: View {
    @Binding private var text: String
    @State private var drafts: [TaskLinkDraft] = [TaskLinkDraft()]
    @State private var lastSyncedText = ""

    init(text: Binding<String>) {
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(drafts) { draft in
                HStack(spacing: 8) {
                    TextField("Title", text: titleBinding(for: draft.id))
                        .taskFormLinkInputStyle()
                    TextField("https://example.com", text: urlBinding(for: draft.id))
                        .taskFormLinkInputStyle()

                    Button {
                        removeDraft(id: draft.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove link")
                    .disabled(drafts.count == 1 && draft.isEmpty)
                }
            }

            Button {
                addDraft()
            } label: {
                Label("Add Link", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            syncDrafts(from: text)
        }
        .onChange(of: text) { _, newValue in
            syncDrafts(from: newValue)
        }
    }

    private func titleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                drafts.first(where: { $0.id == id })?.title ?? ""
            },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[index].title = newValue
                commitDrafts()
            }
        )
    }

    private func urlBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                drafts.first(where: { $0.id == id })?.url ?? ""
            },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[index].url = newValue
                commitDrafts()
            }
        )
    }

    private func addDraft() {
        drafts.append(TaskLinkDraft())
        commitDrafts()
    }

    private func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        if drafts.isEmpty {
            drafts = [TaskLinkDraft()]
        }
        commitDrafts()
    }

    private func commitDrafts() {
        let newText = drafts
            .map { draft in
                let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if title.isEmpty {
                    return draft.url
                }
                return "\(draft.title)\t\(draft.url)"
            }
            .joined(separator: "\n")
        lastSyncedText = newText
        text = newText
    }

    private func syncDrafts(from newText: String) {
        guard newText != lastSyncedText else { return }
        let values = newText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        drafts = values.isEmpty ? [TaskLinkDraft()] : values.map { value in
            let parts = value.components(separatedBy: "\t")
            if parts.count >= 2 {
                return TaskLinkDraft(title: parts[0], url: parts.dropFirst().joined(separator: "\t"))
            }
            return TaskLinkDraft(url: value)
        }
        lastSyncedText = newText
    }
}

private struct TaskLinkDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: String

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(id: UUID = UUID(), title: String = "", url: String = "") {
        self.id = id
        self.title = title
        self.url = url
    }
}

private extension View {
    @ViewBuilder
    func taskFormLinkInputStyle() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
        #else
        self
            .textFieldStyle(.roundedBorder)
        #endif
    }
}
