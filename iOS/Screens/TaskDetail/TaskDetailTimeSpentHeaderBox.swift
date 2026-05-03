import SwiftUI

struct TaskDetailTimeSpentHeaderBox: View {
    let actualDurationMinutes: Int?
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TIME SPENT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(durationText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(actualDurationMinutes == nil ? .secondary : .primary)
            }

            Spacer(minLength: 8)

            Button(action: onEdit) {
                Label(editTitle, systemImage: "clock.badge")
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle(tint: .cyan)
    }

    private var durationText: String {
        actualDurationMinutes.map(TaskDetailHeaderBadgePresentation.durationText(for:)) ?? "Not logged"
    }

    private var editTitle: String {
        actualDurationMinutes == nil ? "Add Time" : "Edit Time"
    }
}
