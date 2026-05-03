import SwiftData
import SwiftUI

struct MacQuickAddSpotlightOverlay: View {
    @Binding var isPresented: Bool
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onCreated: () -> Void

    private var draft: RoutinaQuickAddDraft? {
        RoutinaQuickAddParser.parse(text, calendar: calendar)
    }

    private var canSave: Bool {
        draft != nil && !isSaving
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 0) {
                inputRow

                if let draft {
                    Divider()
                    preview(for: draft)
                }

                if let errorMessage {
                    Divider()
                    errorRow(errorMessage)
                }
            }
            .frame(width: 620)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 30, y: 18)
            .padding(.top, 92)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        .animation(.easeOut(duration: 0.14), value: draft)
        .onAppear {
            isInputFocused = true
        }
        .onExitCommand {
            dismiss()
        }
    }

    private var inputRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            TextField("Water plants every Saturday at 9am #home", text: $text)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .focused($isInputFocused)
                .disabled(isSaving)
                .onSubmit(save)

            if isSaving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("Return")
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(canSave ? .secondary : .tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func preview(for draft: RoutinaQuickAddDraft) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.badge.plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.mint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(draft.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(draft.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if draft.importance != .level2 || draft.urgency != .level2 {
                    Text("\(draft.importance.title) importance • \(draft.urgency.title) urgency")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.red)
                .frame(width: 24)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
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

    private func dismiss() {
        guard !isSaving else { return }
        isPresented = false
    }
}
