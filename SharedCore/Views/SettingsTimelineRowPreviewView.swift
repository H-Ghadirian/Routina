import SwiftUI

struct SettingsTimelineRowPreviewView: View {
    let visibility: HomeTimelineRowVisibility

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingAccessory

            Text("Implement handling for tickets")
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 0)

            if visibility.shows(.kindBadge) {
                timelineKindBadge
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 12, tint: .secondary, tintOpacity: 0.1)
        .overlay(alignment: .topTrailing) {
            if visibility.shows(.rowNumber) {
                rowNumber
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
        }
        .animation(.snappy(duration: 0.22), value: visibility)
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if visibility.shows(.icon) {
            Text("✨")
                .font(.title2)
                .frame(width: 36, height: 36)
                .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)
        } else if visibility.shows(.subtitle) {
            Spacer()
        }
    }

    @ViewBuilder
    private var timelineKindBadge: some View {
        Text("Routine")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: .blue, tintOpacity: 0.15)
            .foregroundStyle(.blue)
    }

    private var rowNumber: some View {
        Text("3")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .routinaGlassPill()
    }
}
