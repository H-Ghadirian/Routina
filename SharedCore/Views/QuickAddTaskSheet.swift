import SwiftData
import SwiftUI

struct QuickAddTaskSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onCreated: () -> Void

    init(onCreated: @escaping () -> Void = {}) {
        self.onCreated = onCreated
    }

    private var draft: RoutinaQuickAddDraft? {
        RoutinaQuickAddParser.parse(text, calendar: calendar)
    }

    private var canSave: Bool {
        draft != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Water plants every Saturday at 9 #home",
                        text: $text,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                    .disabled(isSaving)
                    .submitLabel(.done)
                    .onSubmit(save)
                }

                if let draft {
                    Section("Preview") {
                        Label(draft.name, systemImage: "text.badge.plus")
                            .font(.headline)

                        Text(draft.summaryText)
                            .foregroundStyle(.secondary)

                        if draft.importance != .level2 || draft.urgency != .level2 {
                            Label(
                                "\(draft.importance.title) importance, \(draft.urgency.title) urgency",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Quick Add")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 520, minHeight: 300)
        #endif
    }

    private func save() {
        guard canSave else { return }
        errorMessage = nil
        isSaving = true

        Task { @MainActor in
            defer { isSaving = false }
            do {
                _ = try await RoutinaQuickAddService.createTask(
                    from: text,
                    context: modelContext,
                    calendar: calendar
                )
                onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
