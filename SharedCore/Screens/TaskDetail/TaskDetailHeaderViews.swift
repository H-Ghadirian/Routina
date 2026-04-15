import SwiftUI

struct TaskDetailHeaderBadgeItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color
}

struct TaskDetailHeaderSectionView<TagChipContent: View>: View {
    let title: String
    let statusContextMessage: String?
    let badgeRows: [[TaskDetailHeaderBadgeItem]]
    let tags: [String]
    let tagChip: (String) -> TagChipContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let statusContextMessage {
                    Text(statusContextMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(Array(badgeRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { badge in
                        TaskDetailHeaderBadgeView(item: badge)
                    }
                }
            }

            if !tags.isEmpty {
                TaskDetailHeaderTagsView(tags: tags, tagChip: tagChip)
            }
        }
        .padding(16)
        .detailCardStyle(cornerRadius: 16)
    }
}

struct TaskDetailHeaderBadgeView: View {
    let item: TaskDetailHeaderBadgeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage = item.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint)
                }

                Text(item.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(item.tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(item.tint.opacity(0.24), lineWidth: 1)
        )
    }
}

struct TaskDetailHeaderTagsView<TagChipContent: View>: View {
    let tags: [String]
    let tagChip: (String) -> TagChipContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }
            }
        }
    }
}
