import SwiftUI

struct TaskDetailTimeSpentSheet: View {
    let title: String
    @Binding var minutes: Int
    let showsClearButton: Bool
    let onClear: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Actual Time") {
                    Stepper(value: $minutes, in: 1...1440) {
                        HStack {
                            Text("Time spent")
                            Spacer()
                            Text(RoutineTimeSpentFormatting.compactMinutesText(minutes))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if showsClearButton {
                    Section {
                        Button(role: .destructive, action: onClear) {
                            Label("Clear Time Spent", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(title)
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
        .presentationDetents([.medium])
    }
}
