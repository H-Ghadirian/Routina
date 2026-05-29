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

    var body: some View {
        Section(header: Text("Link")) {
            TextField("https://example.com", text: model.link)
                .routinaAddRoutinePlatformLinkField()
            Text("Add a website to open from the detail screen. If you skip the scheme, https will be used.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
