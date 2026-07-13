import SwiftUI

struct HomeIOSRoutineRowView: View {
    let task: HomeFeature.RoutineDisplay
    let rowNumber: Int
    let metadataText: String?
    let rowVisibility: HomeTaskRowVisibility
    let showTaskTypeBadge: Bool
    let statusBadgeStyle: HomeStatusBadgeStyle?
    let iconBackgroundColor: Color
    let tagColor: (String) -> Color?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leadingAccessories
            content
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var leadingAccessories: some View {
        if rowVisibility.shows(.icon) {
            icon
        } else if rowVisibility.shows(.rowNumber) {
            rowNumberPill
        }
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
            if rowVisibility.shows(.rowNumber) {
                rowNumberPill
                    .offset(x: -10, y: -8)
            }
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
                    .routinaGlassPill()
            }
        }
        .padding(2)
    }

    private var rowNumberPill: some View {
        Text("\(rowNumber)")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .routinaGlassPill()
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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
        Group {
            if shouldShowTaskTypeBadge || shouldShowStatusBadge {
                HStack(spacing: 6) {
                    if shouldShowTaskTypeBadge {
                        HomeTaskTypeBadgeView(taskType: task.scheduleMode.taskType)
                    }
                    if shouldShowStatusBadge {
                        HomeStatusBadgeView(style: statusBadgeStyle)
                    }
                }
            }
        }
    }

    private var shouldShowTaskTypeBadge: Bool {
        showTaskTypeBadge && rowVisibility.shows(.taskTypeBadge)
    }

    private var shouldShowStatusBadge: Bool {
        statusBadgeStyle != nil && rowVisibility.shows(.statusBadge)
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
        if rowVisibility.shows(.tags), !task.tags.isEmpty {
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
        if rowVisibility.shows(.goals), !task.goalTitles.isEmpty {
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
