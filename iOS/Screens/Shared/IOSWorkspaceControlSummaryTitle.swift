import SwiftUI

struct IOSWorkspaceControlSummaryTitle: View {
    let title: String
    let summary: String?
    let onOpenControls: () -> Void

    @ViewBuilder
    var body: some View {
        if let summary {
            Button(action: onOpenControls) {
                titleLabel(summary: summary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), active controls: \(summary)")
            .accessibilityHint("Opens the relevant workspace controls")
        } else {
            Text(title)
                .font(.headline)
                .lineLimit(1)
        }
    }

    private func titleLabel(summary: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 3) {
                Text(summary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
    }
}
