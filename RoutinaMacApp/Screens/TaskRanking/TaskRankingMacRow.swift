import SwiftUI

struct TaskRankingMacRow: View {
    let task: RoutineTask
    let metadata: TaskRankingPresentation.RowMetadata
    let rowNumber: Int?
    let supportsManualOrdering: Bool
    let isSelected: Bool
    let isSearchMatch: Bool
    let visibility: HomeTaskRowVisibility
    let showsPlaces: Bool
    let onSelect: () -> Void
    let onOpenInnerLadder: () -> Void
    let onEditGroup: () -> Void
    let onOrganize: () -> Void
    let onEditTemporalWeight: () -> Void
    let onUseAsGroup: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 9) {
                    leadingIdentity
                    content
                    Spacer(minLength: 2)
                    if canOpenInnerLadder {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 5)
                    }
                }
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(
                canOpenInnerLadder
                    ? "Click to show details; double-click to open the inner Task Ladder"
                    : "Click to show details"
            )
            .accessibilityHint(
                canOpenInnerLadder
                    ? "Double-click to open the inner Task Ladder"
                    : "Shows task details"
            )
            .onMacDoubleClick(enabled: canOpenInnerLadder, perform: onOpenInnerLadder)

            if supportsManualOrdering {
                orderingControls
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            colorBadge
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu { rowContextMenu }
    }

    @ViewBuilder
    private var leadingIdentity: some View {
        if visibility.shows(.icon) || visibility.shows(.rowNumber) {
            VStack(spacing: 4) {
                if visibility.shows(.icon) {
                    taskIcon
                }
                if visibility.shows(.rowNumber), let rowNumber {
                    Text("\(rowNumber)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 34)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metadata.appearance.name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(visibility.allowsMultilineTitles ? nil : 1)
                .fixedSize(horizontal: false, vertical: visibility.allowsMultilineTitles)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsBadges {
                WrappingHStack(horizontalSpacing: 6, verticalSpacing: 5) {
                    rowBadges
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let metadataText = metadata.appearance.metadataText(
                for: visibility,
                showsPlaces: showsPlaces
            ) {
                Text(metadataText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var taskIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(metadata.appearance.color.swiftUIColor?.opacity(0.14) ?? Color.secondary.opacity(0.10))
            Text(metadata.appearance.emoji)
                .font(.body)
            if metadata.appearance.hasImage {
                Image(systemName: "photo.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .padding(2)
                    .background(Color(nsColor: .windowBackgroundColor), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(1)
            }
        }
        .frame(width: 30, height: 30)
    }

    private var orderingControls: some View {
        VStack(spacing: 2) {
            Button(action: onMoveUp) {
                Image(systemName: "chevron.up")
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Move up")

            Button(action: onMoveDown) {
                Image(systemName: "chevron.down")
                    .frame(width: 22, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Move down")
        }
        .foregroundStyle(.secondary)
    }

    private var showsBadges: Bool {
        metadata.isGroup
            || metadata.isTaskGroup
            || metadata.inheritsMetricValue
            || metadata.childCount > 0
            || metadata.temporalTimingLabel != nil
            || visibility.shows(.taskTypeBadge) && metadata.isRepeating
            || visibility.shows(.statusBadge) && metadata.appearance.status != nil
            || visibility.shows(.tags) && !metadata.appearance.tags.isEmpty
            || visibility.shows(.flags) && !metadata.appearance.flags.isEmpty
    }

    @ViewBuilder
    private var rowBadges: some View {
        if metadata.isGroup {
            badge("Group", systemImage: "folder", tint: .secondary)
        }
        if metadata.inheritsMetricValue {
            badge("Inherited", systemImage: "arrow.triangle.branch", tint: .secondary)
        }
        if metadata.isTaskGroup {
            badge("Task group", systemImage: "square.stack.3d.up", tint: .secondary)
        }
        if visibility.shows(.taskTypeBadge), metadata.isRepeating {
            badge("Repeating", systemImage: "repeat", tint: .green)
        }
        if visibility.shows(.statusBadge), let status = metadata.appearance.status {
            badge(status.title, systemImage: status.systemImage, tint: statusTint(status.tone))
        }
        if visibility.shows(.tags) {
            ForEach(metadata.appearance.tags, id: \.self) { tag in
                badge("#\(tag)", tint: .secondary)
            }
        }
        if visibility.shows(.flags) {
            ForEach(metadata.appearance.flags, id: \.self) { flag in
                badge(flag, systemImage: "flag.fill", tint: .orange)
            }
        }
        if let timing = metadata.temporalTimingLabel {
            badge(
                timing,
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tint: .secondary
            )
        }
        if metadata.childCount > 0 {
            badge(
                metadata.childCount == 1 ? "1 task" : "\(metadata.childCount) tasks",
                systemImage: "square.stack.3d.up",
                tint: .secondary
            )
        }
    }

    private func badge(_ title: String, systemImage: String? = nil, tint: Color) -> some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title).lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint.opacity(0.10), in: Capsule())
    }

    private func statusTint(_ tone: TaskRankingRowTone) -> Color {
        switch tone {
        case .secondary: return .secondary
        case .blue: return .blue
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }
        if isSearchMatch {
            return Color.yellow.opacity(0.12)
        }
        guard visibility.shows(.rowColor), let color = metadata.appearance.color.swiftUIColor else {
            return .clear
        }
        return color.opacity(0.10)
    }

    @ViewBuilder
    private var colorBadge: some View {
        if visibility.shows(.colorBadge), let color = metadata.appearance.color.swiftUIColor {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 4, height: 24)
                .padding(.leading, 3)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var rowContextMenu: some View {
        if metadata.isGroup {
            Button("Show Group Details", action: onSelect)
            Button("Open Inner Task Ladder", action: onOpenInnerLadder)
            Button("Edit Group…", action: onEditGroup)
        } else {
            Button("Open Task", action: onSelect)
            Button("Organize in Task Ladder…", action: onOrganize)
            if !task.isOneOffTask {
                if RoutineTaskTemporalWeightResolver.supportsTemporalWeight(task) {
                    Button("Changes over Time…", action: onEditTemporalWeight)
                }
                Button(
                    metadata.isTaskGroup || metadata.childCount > 0
                        ? "Add Task to This Group…"
                        : "Use as Task Ladder Group…",
                    action: onUseAsGroup
                )
            }
            if metadata.isTaskGroup || metadata.childCount > 0 {
                Button("Open Inner Task Ladder", action: onOpenInnerLadder)
            }
        }
        if supportsManualOrdering {
            Divider()
            Button("Move Up", action: onMoveUp)
            Button("Move Down", action: onMoveDown)
        }
    }

    private var canOpenInnerLadder: Bool {
        metadata.isGroup || metadata.isTaskGroup || metadata.childCount > 0
    }
}
