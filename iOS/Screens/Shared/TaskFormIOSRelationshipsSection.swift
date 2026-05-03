import SwiftUI

struct TaskFormIOSRelationshipsSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Relationships")) {
            TaskRelationshipsEditor(
                relationships: model.relationships,
                candidates: model.availableRelationshipTasks,
                addRelationship: model.onAddRelationship,
                removeRelationship: model.onRemoveRelationship
            ) { searchText in
                TextField("Search tasks", text: searchText)
                    .routinaTaskRelationshipSearchFieldPlatform()
            }
            Text("Link this task to another task as related work or a blocker.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
