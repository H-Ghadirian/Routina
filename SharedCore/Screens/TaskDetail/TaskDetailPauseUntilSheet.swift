import SwiftUI

struct TaskDetailPauseUntilSheet: View {
    @Environment(\.dismiss) private var dismiss

    let actionTitle: String
    let onConfirm: (Date) -> Void

    @State private var pauseUntil: Date

    init(
        actionTitle: String,
        now: Date = Date(),
        onConfirm: @escaping (Date) -> Void
    ) {
        self.actionTitle = actionTitle
        self.onConfirm = onConfirm
        let initialDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        _pauseUntil = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Resume date and time",
                        selection: $pauseUntil,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("The task stays out of Calendar scheduling until this time, then becomes active automatically.")
                }
            }
            .navigationTitle(actionTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) {
                        onConfirm(pauseUntil)
                        dismiss()
                    }
                }
            }
        }
    }
}
