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
                    TextField("https://example.com", text: binding(for: draft.id))
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
                    .disabled(drafts.count == 1 && draft.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: {
                drafts.first(where: { $0.id == id })?.value ?? ""
            },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[index].value = newValue
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
        let newText = drafts.map(\.value).joined(separator: "\n")
        lastSyncedText = newText
        text = newText
    }

    private func syncDrafts(from newText: String) {
        guard newText != lastSyncedText else { return }
        let values = newText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        drafts = values.isEmpty
            ? [TaskLinkDraft()]
            : values.map { TaskLinkDraft(value: $0) }
        lastSyncedText = newText
    }
}

private struct TaskLinkDraft: Identifiable, Equatable {
    let id: UUID
    var value: String

    init(id: UUID = UUID(), value: String = "") {
        self.id = id
        self.value = value
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
