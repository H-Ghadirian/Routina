import SwiftUI

struct AddRoutineTagComposerView: View {
    @Binding var tagDraft: String
    let isAddDisabled: Bool
    let onAddTag: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("health, focus, morning", text: $tagDraft)
                .onSubmit(onAddTag)

            Button("Add", action: onAddTag)
                .disabled(isAddDisabled)
        }
    }
}
