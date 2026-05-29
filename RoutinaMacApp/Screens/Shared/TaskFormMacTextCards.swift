import SwiftUI

struct TaskFormMacLinkCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: "Link URL") {
            TextField("https://example.com", text: model.link)
                .textFieldStyle(.roundedBorder)
                .routinaAddRoutinePlatformLinkField()
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
