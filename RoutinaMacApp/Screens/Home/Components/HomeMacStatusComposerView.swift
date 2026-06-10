import SwiftData
import SwiftUI

struct HomeMacStatusComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var statusText = ""
    @State private var saveErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("What are you doing?", text: $statusText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .onSubmit(saveStatus)

                Button(action: saveStatus) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(trimmedStatusText == nil)
                .help("Add status to timeline")
                .accessibilityLabel("Add status to timeline")
            }

            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var trimmedStatusText: String? {
        RoutineNote.cleanedText(statusText)
    }

    private func saveStatus() {
        guard let text = trimmedStatusText else { return }

        let now = Date()
        let note = RoutineNote(
            body: text,
            tags: ["Status"],
            createdAt: now,
            updatedAt: now
        )

        modelContext.insert(note)

        do {
            try modelContext.save()
            statusText = ""
            saveErrorMessage = nil
        } catch {
            modelContext.delete(note)
            saveErrorMessage = "Status was not saved."
        }
    }
}
