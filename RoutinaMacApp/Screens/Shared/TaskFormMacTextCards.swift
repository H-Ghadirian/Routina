import SwiftUI

struct TaskFormMacLinkCard: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        TaskFormMacSectionCard(title: "Links") {
            TaskFormLinksEditor(text: model.link)
            Text(presentation.linkHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormMacNotesCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: "Notes") {
            RoutinaFormattedTextEditor(
                text: model.notes,
                placeholder: "Add notes, reminders, or context",
                minHeight: 120,
                backgroundColor: Color(nsColor: .textBackgroundColor),
                strokeColor: Color.gray.opacity(0.18)
            )
        }
    }
}
