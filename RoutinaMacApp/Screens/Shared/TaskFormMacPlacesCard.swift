import Foundation
import SwiftUI

struct TaskFormMacPlacesCard: View {
    let model: TaskFormModel
    let onManagePlaces: () -> Void

    var body: some View {
        TaskFormMacSectionCard(title: "Places") {
            HStack(spacing: 10) {
                TaskFormPlaceSelectionMenu(model: model)
                    .frame(minWidth: 160, alignment: .leading)

                Button {
                    onManagePlaces()
                } label: {
                    Label("Manage", systemImage: "map")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
