import SwiftUI

enum HomeMacTaskRowSecondaryLabel {
    case plannedToday
    case tag(String)
    case flag(String)
    case goal(String)

    var overflowDescription: String {
        switch self {
        case .plannedToday:
            return "Planned today"
        case let .tag(tag):
            return "Tag: \(tag)"
        case let .flag(flag):
            return "Flag: \(flag)"
        case let .goal(goal):
            return "Goal: \(goal)"
        }
    }
}

struct HomeMacTaskRowSecondaryLabels: View {
    let labels: [HomeMacTaskRowSecondaryLabel]
    let statusBadgeStyle: HomeStatusBadgeStyle?
    let allowsMultilineDetails: Bool
    let tagTint: (String) -> Color

    var body: some View {
        if allowsMultilineDetails {
            multilineLabels
        } else {
            compactLabels
        }
    }

    private var multilineLabels: some View {
        HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 5) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                rowLabel(label)
            }

            if let statusBadgeStyle {
                HomeStatusBadgeView(style: statusBadgeStyle)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
    }

    private var compactLabels: some View {
        HStack(alignment: .center, spacing: 6) {
            if !labels.isEmpty {
                HomeMacTaskRowCompactLabelsLayout(labelCount: labels.count, spacing: 6) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                        rowLabel(label)
                    }

                    ForEach(1...labels.count, id: \.self) { hiddenCount in
                        overflowChip(
                            hiddenCount: hiddenCount,
                            hiddenLabels: Array(labels.suffix(hiddenCount))
                        )
                    }
                }
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(compactAccessibilityLabel)
            }

            Spacer(minLength: labels.isEmpty ? 0 : 6)

            if let statusBadgeStyle {
                HomeStatusBadgeView(style: statusBadgeStyle)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
    }

    private var compactAccessibilityLabel: String {
        labels.map(\.overflowDescription).joined(separator: ", ")
    }

    @ViewBuilder
    private func rowLabel(_ label: HomeMacTaskRowSecondaryLabel) -> some View {
        switch label {
        case .plannedToday:
            Label("Planned today", systemImage: "calendar")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .routinaGlassPill(tint: .accentColor, tintOpacity: 0.14)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.accentColor.opacity(0.30), lineWidth: 0.5)
                )
                .accessibilityLabel("Planned for today")
        case let .tag(tag):
            tagChip(tag)
        case let .flag(flag):
            flagChip(flag)
        case let .goal(goal):
            Label(goal, systemImage: "target")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let tint = tagTint(tag)

        return Text("#\(tag)")
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: tint, tintOpacity: 0.14)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 0.5)
            )
    }

    private func flagChip(_ flag: String) -> some View {
        Label(flag, systemImage: "flag.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: .orange, tintOpacity: 0.14)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 0.5)
            )
    }

    private func overflowChip(
        hiddenCount: Int,
        hiddenLabels: [HomeMacTaskRowSecondaryLabel]
    ) -> some View {
        let hiddenDescription = hiddenLabels
            .map(\.overflowDescription)
            .joined(separator: ", ")

        return Text("+\(hiddenCount) more")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: .secondary, tintOpacity: 0.10)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5)
            )
            .help(hiddenDescription)
            .accessibilityLabel("\(hiddenCount) more row details: \(hiddenDescription)")
    }
}

private struct HomeMacTaskRowCompactLabelsLayout: Layout {
    struct Cache {
        var sizes: [CGSize]
    }

    let labelCount: Int
    let spacing: CGFloat

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        selection(maxWidth: proposal.width ?? .infinity, sizes: cache.sizes).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let selection = selection(maxWidth: bounds.width, sizes: cache.sizes)
        var x = bounds.minX

        for index in 0..<selection.visibleLabelCount {
            let size = cache.sizes[index]
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.midY - size.height / 2),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
        }

        if let overflowIndex = selection.overflowIndex {
            let size = cache.sizes[overflowIndex]
            subviews[overflowIndex].place(
                at: CGPoint(x: x, y: bounds.midY - size.height / 2),
                proposal: ProposedViewSize(size)
            )
        }

        for index in subviews.indices
        where index >= selection.visibleLabelCount && index != selection.overflowIndex {
            let size = cache.sizes[index]
            subviews[index].place(
                at: CGPoint(
                    x: bounds.maxX + size.width + 1,
                    y: bounds.maxY + size.height + 1
                ),
                proposal: ProposedViewSize(size)
            )
        }
    }

    private func selection(maxWidth: CGFloat, sizes: [CGSize]) -> Selection {
        guard labelCount > 0, sizes.count >= labelCount * 2 else {
            return Selection(visibleLabelCount: 0, overflowIndex: nil, size: .zero)
        }

        var prefixWidths = Array(repeating: CGFloat.zero, count: labelCount + 1)
        for index in 0..<labelCount {
            prefixWidths[index + 1] = prefixWidths[index]
                + (index == 0 ? 0 : spacing)
                + sizes[index].width
        }

        if prefixWidths[labelCount] <= maxWidth {
            return Selection(
                visibleLabelCount: labelCount,
                overflowIndex: nil,
                size: CGSize(
                    width: prefixWidths[labelCount],
                    height: sizes.prefix(labelCount).map(\.height).max() ?? 0
                )
            )
        }

        for visibleCount in stride(from: labelCount - 1, through: 0, by: -1) {
            let hiddenCount = labelCount - visibleCount
            let overflowIndex = labelCount + hiddenCount - 1
            let candidateWidth = prefixWidths[visibleCount]
                + (visibleCount == 0 ? 0 : spacing)
                + sizes[overflowIndex].width

            if candidateWidth <= maxWidth || visibleCount == 0 {
                let labelHeight = sizes.prefix(visibleCount).map(\.height).max() ?? 0
                return Selection(
                    visibleLabelCount: visibleCount,
                    overflowIndex: overflowIndex,
                    size: CGSize(
                        width: candidateWidth,
                        height: max(labelHeight, sizes[overflowIndex].height)
                    )
                )
            }
        }

        return Selection(visibleLabelCount: 0, overflowIndex: nil, size: .zero)
    }

    private struct Selection {
        let visibleLabelCount: Int
        let overflowIndex: Int?
        let size: CGSize
    }
}
