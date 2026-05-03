import SwiftUI

struct TaskFormIOSNotesSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Notes")) {
            TextField("Add notes", text: model.notes, axis: .vertical)
                .lineLimit(4...8)
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
