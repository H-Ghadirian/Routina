import SwiftUI

struct BacklogMacTaskRow<MoveMenu: View>: View {
    let task: RoutineTask
    let row: BacklogTaskRowPresentation
    let rowNumber: Int?
    let pathTitle: String
    let indentation: CGFloat
    let isSelected: Bool
    let visibility: HomeTaskRowVisibility
    let showsPlaces: Bool
    let showsTomorrowPlanningShortcut: Bool
    let tagColors: [String: String]
    let onOpen: () -> Void
    let onPlanForToday: () -> Void
    let onPlanForTomorrow: () -> Void
    let onChoosePlanDate: () -> Void
    let onClearPlan: () -> Void
    let onMoveToMainTaskList: () -> Void
    @ViewBuilder let moveMenu: () -> MoveMenu

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 9) {
                leadingIconAndNumber
                content
                Spacer(minLength: 4)
                if row.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 10 + indentation)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
            .overlay(alignment: .trailing) {
                colorBadge
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(row.name) task details")
        .contextMenu {
            Button("Open Task", action: onOpen)
            Menu("Move to Backlog", content: moveMenu)
            if task.customTaskSectionID != nil {
                Button("Move to Main Task List", action: onMoveToMainTaskList)
            }
            if task.supportsStoredPlanning {
                Divider()
                Menu("Plan to do") {
                    Button("Today", action: onPlanForToday)
                    if showsTomorrowPlanningShortcut {
                        Button("Tomorrow", action: onPlanForTomorrow)
                    }
                    Button("Choose Date...", action: onChoosePlanDate)
                    if task.plannedDate != nil {
                        Button("Clear Plan", action: onClearPlan)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var leadingIconAndNumber: some View {
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
        VStack(alignment: .leading, spacing: 3) {
            Text(row.name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .lineLimit(visibility.allowsMultilineTitles ? nil : 1)
                .fixedSize(horizontal: false, vertical: visibility.allowsMultilineTitles)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            subtitle

            if showsLabels {
                WrappingHStack(horizontalSpacing: 5, verticalSpacing: 5) {
                    labels
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let metadataText = row.metadataText(for: visibility, showsPlaces: showsPlaces) {
                Text(metadataText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var subtitle: some View {
        let values = [pathTitle] + (row.hidingFlags.isEmpty ? [] : [row.hidingFlags.joined(separator: ", ")])
        return Text(values.joined(separator: " • "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var taskIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(row.color.swiftUIColor?.opacity(0.14) ?? Color.secondary.opacity(0.10))
            Text(row.emoji)
                .font(.body)
            if row.hasImage {
                Image(systemName: "photo.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(2)
                    .background(Color(nsColor: .windowBackgroundColor), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(1)
            }
        }
        .frame(width: 30, height: 30)
    }

    private var showsLabels: Bool {
        visibility.shows(.taskTypeBadge)
            || visibility.shows(.statusBadge) && row.status != nil
            || visibility.shows(.tags) && !row.tags.isEmpty
            || visibility.shows(.flags) && !row.flags.isEmpty
    }

    @ViewBuilder
    private var labels: some View {
        if visibility.shows(.taskTypeBadge) {
            badge(
                row.isOneOffTask ? "One-time" : "Repeating",
                systemImage: row.isOneOffTask ? "checklist" : "repeat",
                tint: row.isOneOffTask ? .blue : .green
            )
        }
        if visibility.shows(.statusBadge), let status = row.status {
            badge(status.title, systemImage: status.systemImage, tint: statusTint(status.tone))
        }
        if visibility.shows(.tags) {
            ForEach(row.tags, id: \.self) { tag in
                badge("#\(tag)", tint: tagTint(tag))
            }
        }
        if visibility.shows(.flags) {
            ForEach(row.flags, id: \.self) { flag in
                badge(flag, systemImage: "flag.fill", tint: .orange)
            }
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
        .background(tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(tint.opacity(0.24), lineWidth: 0.5)
        }
    }

    private func statusTint(_ tone: BacklogTaskRowTone) -> Color {
        switch tone {
        case .secondary: return .secondary
        case .blue: return .blue
        case .green: return .green
        case .indigo: return .indigo
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        }
    }

    private func tagTint(_ tag: String) -> Color {
        guard let normalizedTag = RoutineTag.normalized(tag), let hex = tagColors[normalizedTag] else {
            return .secondary
        }
        return Color(hex: hex)
    }

    private var trailingPadding: CGFloat {
        visibility.shows(.colorBadge) && row.color.swiftUIColor != nil ? 28 : 10
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        }
        guard visibility.shows(.rowColor), let color = row.color.swiftUIColor else {
            return .clear
        }
        return color.opacity(0.10)
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.42)
        }
        guard visibility.shows(.rowColor), let color = row.color.swiftUIColor else {
            return .clear
        }
        return color.opacity(0.28)
    }

    @ViewBuilder
    private var colorBadge: some View {
        if visibility.shows(.colorBadge), let color = row.color.swiftUIColor {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 18)
                .padding(.trailing, 10)
                .accessibilityHidden(true)
        }
    }
}
