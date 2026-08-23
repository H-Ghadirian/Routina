import SwiftUI

/// A compact, always-visible Task Ladder summary. Values are directly editable
/// unless a Changes over time rule makes Task Details a read-only review
/// surface; the container intentionally has no aggregate priority or disclosure
/// state.
struct TaskDetailTaskLadderValuesBox<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("TASK LADDER VALUES", systemImage: "square.grid.2x2.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
        )
    }
}
