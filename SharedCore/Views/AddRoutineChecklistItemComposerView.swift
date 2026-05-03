import SwiftUI

struct AddRoutineChecklistItemComposerView: View {
    @Binding var titleDraft: String
    @Binding var intervalDays: Int
    let showsInterval: Bool
    let intervalLabel: (Int) -> String
    let isAddDisabled: Bool
    let onAddItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bread", text: $titleDraft)
                .onSubmit(onAddItem)

            if showsInterval {
                Stepper(value: $intervalDays, in: 1...365) {
                    Text(intervalLabel(intervalDays))
                }
            }

            Button("Add Item", action: onAddItem)
                .disabled(isAddDisabled)
        }
    }
}
