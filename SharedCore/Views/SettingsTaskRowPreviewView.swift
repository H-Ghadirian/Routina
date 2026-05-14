import SwiftUI

struct SettingsTaskRowPreviewView: View {
    let visibility: HomeTaskRowVisibility
    var showsTaskTypeBadge = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingAccessory
            content
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 12, tint: .teal, tintOpacity: 0.12)
        .animation(.snappy(duration: 0.22), value: visibility)
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if visibility.shows(.icon) {
            VStack(spacing: 4) {
                icon
                if visibility.shows(.rowNumber) {
                    rowNumber
                }
            }
            .frame(width: 44)
        } else if visibility.shows(.rowNumber) {
            rowNumber
        }
    }

    private var icon: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.teal.opacity(0.24))

            Text("✨")
                .font(.title3)

            Image(systemName: "photo.fill")
                .font(.caption2)
                .foregroundStyle(.primary)
                .padding(3)
                .routinaGlassPill()
                .padding(2)
        }
        .frame(width: 42, height: 42)
    }

    private var rowNumber: some View {
        Text("3")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .routinaGlassPill()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow

            if showsTaskTypeBadge, visibility.shows(.taskTypeBadge) {
                HomeTaskTypeBadgeView(isTodo: false)
            }

            if let metadataText {
                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            tags
            goals
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Implement handling for tickets")
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            if visibility.shows(.statusBadge) {
                HomeStatusBadgeView(
                    style: HomeStatusBadgeStyle(
                        title: "In Progress",
                        systemImage: "arrow.clockwise.circle.fill",
                        foregroundColor: .blue,
                        backgroundColor: Color.blue.opacity(0.14)
                    )
                )
            }
        }
    }

    private var metadataText: String? {
        let items = [
            visibility.shows(.schedule) ? "Every 3 days" : nil,
            visibility.shows(.priority) ? "Medium" : nil,
            visibility.shows(.progress) ? "Step 2 of 4" : nil,
            visibility.shows(.pressure) ? "High pressure" : nil,
            visibility.shows(.steps) ? "Next: Draft response" : nil,
            visibility.shows(.place) ? "At Office" : nil
        ].compactMap { $0 }

        guard !items.isEmpty else { return nil }
        return items.joined(separator: " • ")
    }

    @ViewBuilder
    private var tags: some View {
        if visibility.shows(.tags) {
            HStack(spacing: 6) {
                previewTag("HSE", color: .green, tintOpacity: 0.16)
                previewTag("Ticket", color: .secondary, tintOpacity: 0.10)
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var goals: some View {
        if visibility.shows(.goals) {
            Label("Less stress at work", systemImage: "target")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func previewTag(_ title: String, color: Color, tintOpacity: Double) -> some View {
        Text("#\(title)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: color, tintOpacity: tintOpacity)
    }
}
