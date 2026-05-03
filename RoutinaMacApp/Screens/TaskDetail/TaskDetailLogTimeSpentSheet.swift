import SwiftUI

struct TaskDetailLogTimeSpentSheet: View {
    @Binding var minutes: Int

    let showsClearButton: Bool
    let onClear: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Spent")
                    .font(.title3.weight(.semibold))
                Text("Record the actual time for this completion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: $minutes, in: 1...1440) {
                HStack {
                    Text("Time spent")
                    Spacer()
                    Text(RoutineTimeSpentFormatting.compactMinutesText(minutes))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if showsClearButton {
                    Button(role: .destructive, action: onClear) {
                        Label("Clear", systemImage: "trash")
                    }
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 420)
        .padding(24)
    }
}
