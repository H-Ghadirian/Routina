import SwiftUI

private enum TaskDetailHeaderSectionMetrics {
    static let titleAccessorySpacing: CGFloat = 12
}

struct TaskDetailHeaderSectionView<TagChipContent: View, AdditionalContent: View, HeaderAccessory: View>: View {
    let title: String
    let titleDragPayload: String?
    let statusContextMessage: String?
    let badgeRows: [[TaskDetailHeaderBadgeItem]]
    let tags: [String]
    let tagChip: (String) -> TagChipContent
    let additionalContent: () -> AdditionalContent
    let headerAccessory: () -> HeaderAccessory
    @State private var headerMetrics: [TaskDetailHeaderSectionViewMetric: CGFloat] = [:]

    init(
        title: String,
        titleDragPayload: String? = nil,
        statusContextMessage: String?,
        badgeRows: [[TaskDetailHeaderBadgeItem]],
        tags: [String],
        @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory,
        @ViewBuilder tagChip: @escaping (String) -> TagChipContent,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent
    ) {
        self.title = title
        self.titleDragPayload = titleDragPayload
        self.statusContextMessage = statusContextMessage
        self.badgeRows = badgeRows
        self.tags = tags
        self.tagChip = tagChip
        self.additionalContent = additionalContent
        self.headerAccessory = headerAccessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerLayout
                .background(headerMetricReader(.availableWidth))
                .overlay(alignment: .topLeading) {
                    titleWidthProbe
                }
                .onPreferenceChange(TaskDetailHeaderMetricPreferenceKey.self) { metrics in
                    headerMetrics = metrics
                }

            ForEach(Array(badgeRows.enumerated()), id: \.offset) { _, row in
                TaskDetailHeaderBadgeRowView(row: row)
            }

            additionalContent()

            if !tags.isEmpty {
                TaskDetailHeaderTagsView(tags: tags, tagChip: tagChip)
            }
        }
        .padding(16)
        .detailCardStyle(cornerRadius: 16)
    }

    @ViewBuilder
    private var headerLayout: some View {
        if usesStackedHeaderLayout {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer(minLength: 0)
                    measuredHeaderAccessory
                }

                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(alignment: .top, spacing: TaskDetailHeaderSectionMetrics.titleAccessorySpacing) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                measuredHeaderAccessory
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleText

            if let statusContextMessage {
                Text(statusContextMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var titleText: some View {
        if let titleDragPayload {
            baseTitleText
                .draggable(titleDragPayload)
                .help("Drag to place this task on the planner")
        } else {
            baseTitleText
        }
    }

    private var baseTitleText: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .taskDetailCopyableText(title)
    }

    private var measuredHeaderAccessory: some View {
        headerAccessory()
            .fixedSize(horizontal: true, vertical: false)
            .background(headerMetricReader(.accessoryWidth))
    }

    private var titleWidthProbe: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(headerMetricReader(.titleWidth))
            .opacity(0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var usesStackedHeaderLayout: Bool {
        guard
            let availableWidth = headerMetrics[.availableWidth],
            let titleWidth = headerMetrics[.titleWidth],
            availableWidth > 0
        else {
            return false
        }

        let accessoryWidth = headerMetrics[.accessoryWidth] ?? 0
        guard accessoryWidth > 0.5 else {
            return false
        }

        return titleWidth + accessoryWidth + TaskDetailHeaderSectionMetrics.titleAccessorySpacing > availableWidth
    }

    private func headerMetricReader(_ metric: TaskDetailHeaderSectionViewMetric) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TaskDetailHeaderMetricPreferenceKey.self,
                value: [metric: proxy.size.width]
            )
        }
    }
}

private struct TaskDetailHeaderMetricPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [TaskDetailHeaderSectionViewMetric: CGFloat] = [:]

    static func reduce(
        value: inout [TaskDetailHeaderSectionViewMetric: CGFloat],
        nextValue: () -> [TaskDetailHeaderSectionViewMetric: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private enum TaskDetailHeaderSectionViewMetric: Hashable {
    case availableWidth
    case titleWidth
    case accessoryWidth
}

extension TaskDetailHeaderSectionView where HeaderAccessory == EmptyView {
    init(
        title: String,
        titleDragPayload: String? = nil,
        statusContextMessage: String?,
        badgeRows: [[TaskDetailHeaderBadgeItem]],
        tags: [String],
        @ViewBuilder tagChip: @escaping (String) -> TagChipContent,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent
    ) {
        self.init(
            title: title,
            titleDragPayload: titleDragPayload,
            statusContextMessage: statusContextMessage,
            badgeRows: badgeRows,
            tags: tags,
            headerAccessory: { EmptyView() },
            tagChip: tagChip,
            additionalContent: additionalContent
        )
    }
}

extension TaskDetailHeaderSectionView where AdditionalContent == EmptyView, HeaderAccessory == EmptyView {
    init(
        title: String,
        titleDragPayload: String? = nil,
        statusContextMessage: String?,
        badgeRows: [[TaskDetailHeaderBadgeItem]],
        tags: [String],
        @ViewBuilder tagChip: @escaping (String) -> TagChipContent
    ) {
        self.init(
            title: title,
            titleDragPayload: titleDragPayload,
            statusContextMessage: statusContextMessage,
            badgeRows: badgeRows,
            tags: tags,
            headerAccessory: { EmptyView() },
            tagChip: tagChip,
            additionalContent: { EmptyView() }
        )
    }
}

struct TaskDetailHeaderBadgeView: View {
    let item: TaskDetailHeaderBadgeItem
    var minHeight: CGFloat? = nil
    var fillsAvailableHeight = false

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
        .frame(
            maxWidth: .infinity,
            minHeight: minHeight,
            maxHeight: fillsAvailableHeight ? .infinity : nil,
            alignment: .topLeading
        )
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

private struct TaskDetailHeaderBadgeRowView: View {
    let row: [TaskDetailHeaderBadgeItem]

    var body: some View {
        TaskDetailHeaderBadgeRowLayout(spacing: 8) {
            ForEach(row) { badge in
                TaskDetailHeaderBadgeView(item: badge, fillsAvailableHeight: true)
            }
        }
    }
}

private struct TaskDetailHeaderBadgeRowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let totalSpacing = totalSpacing(for: subviews.count)
        if let proposedWidth = proposal.width {
            let itemWidth = itemWidth(in: proposedWidth, subviewCount: subviews.count)
            let rowHeight = subviews
                .map { $0.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil)).height }
                .max() ?? 0

            return CGSize(width: proposedWidth, height: rowHeight)
        }

        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = sizes.reduce(totalSpacing) { $0 + $1.width }
        let rowHeight = sizes.map(\.height).max() ?? 0
        return CGSize(width: rowWidth, height: rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let itemWidth = itemWidth(in: bounds.width, subviewCount: subviews.count)
        for index in subviews.indices {
            let x = bounds.minX + CGFloat(index) * (itemWidth + spacing)
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: itemWidth, height: bounds.height)
            )
        }
    }

    private func totalSpacing(for subviewCount: Int) -> CGFloat {
        spacing * CGFloat(max(0, subviewCount - 1))
    }

    private func itemWidth(in width: CGFloat, subviewCount: Int) -> CGFloat {
        let totalSpacing = totalSpacing(for: subviewCount)
        return max(0, width - totalSpacing) / CGFloat(subviewCount)
    }
}

struct DetailHeaderBoxStyle: ViewModifier {
    var tint: Color = .secondary
    var minHeight: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }
}

extension View {
    func detailHeaderBoxStyle(tint: Color = .secondary, minHeight: CGFloat? = nil) -> some View {
        modifier(DetailHeaderBoxStyle(tint: tint, minHeight: minHeight))
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

extension View {
    func detailCardStyle(cornerRadius: CGFloat = 12) -> some View {
        background(TaskDetailPlatformStyle.summaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
            )
    }
}
