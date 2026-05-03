import SwiftUI

struct HomeIOSRoutineRowView: View {
    let task: HomeFeature.RoutineDisplay
    let rowNumber: Int
    let metadataText: String?
    let showTaskTypeBadge: Bool
    let statusBadgeStyle: HomeStatusBadgeStyle?
    let iconBackgroundColor: Color
    let tagColor: (String) -> Color?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon
            content
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(iconBackgroundColor)
            Text(task.emoji)
                .font(.title3)
            if task.hasImage {
                imageIndicator
            }
        }
        .frame(width: 40, height: 40)
        .overlay(alignment: .topLeading) {
            rowNumberBadge
        }
    }

    private var imageIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "photo.fill")
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .padding(4)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(2)
    }

    private var rowNumberBadge: some View {
        Text("\(rowNumber)")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .offset(x: -10, y: -8)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.name)
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            badges
            metadata
            tags
            goals
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if showTaskTypeBadge {
                HomeTaskTypeBadgeView(isTodo: task.isOneOffTask)
            }
            HomeStatusBadgeView(style: statusBadgeStyle)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if let metadataText {
            Text(metadataText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var tags: some View {
        if !task.tags.isEmpty {
            HStack(spacing: 8) {
                ForEach(task.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundStyle(tagColor(tag) ?? .secondary)
                        .lineLimit(1)
                }
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var goals: some View {
        if !task.goalTitles.isEmpty {
            HStack(spacing: 8) {
                ForEach(task.goalTitles, id: \.self) { goal in
                    Label(goal, systemImage: "target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .lineLimit(1)
        }
    }
}
