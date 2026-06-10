import SwiftUI

struct TaskPlanningDatePickerSheet: View {
    @Binding var date: Date
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Plan date",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
            .navigationTitle("Plan to do")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium])
#endif
    }
}
