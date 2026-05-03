import SwiftUI

struct AddRoutineStepComposerView: View {
    @Binding var stepDraft: String
    let isAddDisabled: Bool
    let onAddStep: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Wash clothes", text: $stepDraft)
                .onSubmit(onAddStep)

            Button("Add", action: onAddStep)
                .disabled(isAddDisabled)
        }
    }
}
