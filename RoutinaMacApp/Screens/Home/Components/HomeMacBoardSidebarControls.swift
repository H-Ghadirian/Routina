import SwiftUI

struct HomeMacBoardCreationFieldView: View {
    let placeholder: String
    @Binding var title: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            TextField(
                placeholder,
                text: $title
            )
            .textFieldStyle(.plain)
            .font(.caption.weight(.semibold))
            .focused(focus)
            .onSubmit {
                onConfirm()
            }
            .onAppear {
                focus.wrappedValue = true
            }

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

struct HomeMacBoardSprintRenameFieldView: View {
    @Binding var title: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            TextField(
                "Sprint name...",
                text: $title
            )
            .textFieldStyle(.plain)
            .font(.caption.weight(.semibold))
            .focused(focus)
            .onSubmit { onConfirm() }
            .onAppear {
                focus.wrappedValue = true
            }

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        )
    }
}

struct HomeMacBoardScopeButton: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

struct HomeMacBoardSprintScopeRow: View {
    let sprint: BoardSprint
    let dateSummary: String?
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameTitle: String
    let renameFocus: FocusState<Bool>.Binding
    let onSelect: () -> Void
    let onRename: () -> Void
    let onRenameTitleChanged: (String) -> Void
    let onRenameConfirm: () -> Void
    let onRenameCancel: () -> Void
    let onStart: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if isRenaming {
            HomeMacBoardSprintRenameFieldView(
                title: renameBinding,
                onConfirm: onRenameConfirm,
                onCancel: onRenameCancel,
                focus: renameFocus
            )
        } else {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(boardSprintTint(for: sprint.status))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sprint.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let dateSummary {
                            Text(dateSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(sprint.status.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename", action: onRename)

                if sprint.status != .active {
                    Button("Set as Active", action: onStart)
                }

                Divider()

                Button("Delete", role: .destructive, action: onDelete)
                    .disabled(sprint.status == .active)
            }
        }
    }

    private var renameBinding: Binding<String> {
        Binding(
            get: { renameTitle },
            set: { onRenameTitleChanged($0) }
        )
    }

    private func boardSprintTint(for status: SprintStatus) -> Color {
        switch status {
        case .planned:
            return .orange
        case .active:
            return .green
        case .finished:
            return .secondary
        }
    }
}
