import SwiftUI

/// Keeps guided-review progress visually separate from an inline navigation title.
struct GuidedReviewProgressHeader: View {
    let currentTaskNumber: Int
    let totalTaskCount: Int
    let progressValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task \(currentTaskNumber) of \(totalTaskCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ProgressView(value: progressValue)
                .tint(.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Guided review progress")
        .accessibilityValue("Task \(currentTaskNumber) of \(totalTaskCount)")
    }
}
