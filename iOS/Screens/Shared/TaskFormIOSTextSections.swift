import SwiftUI

struct TaskFormIOSNotesSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Notes")) {
            RoutinaFormattedTextEditor(
                text: model.notes,
                placeholder: "Add notes",
                minHeight: 110
            )
            Text(presentation.notesHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSLinkSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Links")) {
            TaskFormLinksEditor(text: model.link)
            Text(presentation.linkHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
