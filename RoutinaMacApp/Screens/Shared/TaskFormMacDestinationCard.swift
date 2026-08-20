import SwiftUI

struct TaskFormMacDestinationCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: "Address") {
            TaskDestinationFormEditor(
                address: model.destinationAddress,
                coordinate: model.destinationCoordinate
            )
        }
    }
}
