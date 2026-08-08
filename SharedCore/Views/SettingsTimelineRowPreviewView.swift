import SwiftUI

struct SettingsTimelineRowPreviewView: View {
    let visibility: HomeTimelineRowVisibility

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leadingAccessory

            VStack(alignment: .leading, spacing: 2) {
                Text("Implement handling for tickets")
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .layoutPriority(1)

                if visibility.shows(.subtitle) {
                    Text("Yesterday · Completed task")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if visibility.shows(.kindBadge) {
                timelineKindBadge
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaScrollingRoundedFill(cornerRadius: 12, tint: .secondary, tintOpacity: 0.1)
        .animation(.snappy(duration: 0.22), value: visibility)
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if visibility.shows(.icon) {
            Text("✨")
                .font(.title2)
                .frame(width: 36, height: 36)
                .routinaScrollingRoundedFill(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)
                .overlay(alignment: .topLeading) {
                    if visibility.shows(.rowNumber) {
                        rowNumber
                            .offset(x: -8, y: -6)
                    }
                }
        } else if visibility.shows(.rowNumber) {
            rowNumber
        }
    }

    @ViewBuilder
    private var timelineKindBadge: some View {
        Text("Routine")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .routinaScrollingPillFill(tint: .blue, tintOpacity: 0.15)
            .foregroundStyle(.blue)
    }

    private var rowNumber: some View {
        Text("3")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .routinaScrollingPillFill(tint: .secondary, tintOpacity: 0.14)
    }
}
