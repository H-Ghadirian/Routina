import SwiftUI

struct TaskFormIOSEventsSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Events")) {
            TaskFormLinkedEventsContent(
                events: model.availableEvents,
                selectedEventIDs: model.selectedEventIDs,
                onToggleEvent: model.onToggleEventSelection
            )
        }
    }
}
