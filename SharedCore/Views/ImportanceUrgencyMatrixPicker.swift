import SwiftUI

struct ImportanceUrgencyMatrixPicker: View {
    private enum SelectionMode {
        case task
        case filter(Binding<ImportanceUrgencyFilterCell?>)
    }

    @Binding private var importance: RoutineTaskImportance
    @Binding private var urgency: RoutineTaskUrgency
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let selectionMode: SelectionMode
    private let showsSummaryChip: Bool

    private let importanceLevels = RoutineTaskImportance.allCases.sorted { $0.sortOrder > $1.sortOrder }
    private let urgencyLevels = RoutineTaskUrgency.allCases.sorted { $0.sortOrder < $1.sortOrder }
    private let rowHeaderWidth: CGFloat = 86

    init(
        importance: Binding<RoutineTaskImportance>,
        urgency: Binding<RoutineTaskUrgency>,
        showsSummaryChip: Bool = true
    ) {
        self._importance = importance
        self._urgency = urgency
        self.selectionMode = .task
        self.showsSummaryChip = showsSummaryChip
    }

    init(
        selectedFilter: Binding<ImportanceUrgencyFilterCell?>,
        showsSummaryChip: Bool = true
    ) {
        self._importance = .constant(selectedFilter.wrappedValue?.importance ?? .level1)
        self._urgency = .constant(selectedFilter.wrappedValue?.urgency ?? .level1)
        self.selectionMode = .filter(selectedFilter)
        self.showsSummaryChip = showsSummaryChip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsSummaryChip {
                summaryChip(
                    title: summaryChipTitle,
                    systemImage: summaryChipSystemImage,
                    color: summaryChipColor,
                    emphasized: true
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    importanceAxisHeader
                        .padding(6)
                        .frame(width: rowHeaderWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        urgencyAxisHeader

                        HStack(spacing: 8) {
                            ForEach(urgencyLevels, id: \.self) { level in
                                axisLevelLabel(
                                    level.shortTitle,
                                    isSelected: displayedUrgency == level
                                )
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.bottom, 2)
                    }
                    .padding(6)
                    .axisLabelBorder()
                }

                ForEach(importanceLevels, id: \.self) { importanceLevel in
                    HStack(spacing: 8) {
                        axisLevelLabel(
                            importanceLevel.shortTitle,
                            isSelected: displayedImportance == importanceLevel
                        )
                            .padding(.horizontal, 6)
                            .frame(width: rowHeaderWidth, alignment: .center)

                        HStack(spacing: 8) {
                            ForEach(urgencyLevels, id: \.self) { urgencyLevel in
                                matrixCell(
                                    importanceLevel: importanceLevel,
                                    urgencyLevel: urgencyLevel
                                )
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(axisBorderColor, lineWidth: 1)
                    .frame(width: rowHeaderWidth)
                    .allowsHitTesting(false)
            }
        }
    }

    private var axisBorderColor: Color {
        Color.primary.opacity(0.14)
    }

    private var importanceAxisHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .imageScale(.small)
                Text("Importance")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private var urgencyAxisHeader: some View {
        HStack(spacing: 4) {
            Text("Urgency")
            Image(systemName: "arrow.right")
                .imageScale(.small)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func axisLevelLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 24, height: 24)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func matrixCell(
        importanceLevel: RoutineTaskImportance,
        urgencyLevel: RoutineTaskUrgency
    ) -> some View {
        let isSelected = displayedImportance == importanceLevel && displayedUrgency == urgencyLevel

        return Button {
            switch selectionMode {
            case .task:
                importance = importanceLevel
                urgency = urgencyLevel
            case let .filter(selectedFilter):
                let newCell = ImportanceUrgencyFilterCell(importance: importanceLevel, urgency: urgencyLevel)
                let nextCell = selectedFilter.wrappedValue == newCell ? nil : newCell
                selectedFilter.wrappedValue = ImportanceUrgencyFilterCell.normalized(nextCell)
            }
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cellColor(importanceLevel: importanceLevel, urgencyLevel: urgencyLevel))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.10),
                            lineWidth: isSelected ? 3 : 1
                        )
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white, Color.accentColor)
                    } else {
                        Text(priorityTitle(for: importanceLevel, urgencyLevel))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.72))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(importanceLevel.title) importance, \(urgencyLevel.title) urgency")
        .accessibilityValue(isSelected ? "Selected" : priorityTitle(for: importanceLevel, urgencyLevel))
    }

    private var displayedImportance: RoutineTaskImportance {
        switch selectionMode {
        case .task:
            return importance
        case let .filter(selectedFilter):
            return selectedFilter.wrappedValue?.importance ?? .level1
        }
    }

    private var displayedUrgency: RoutineTaskUrgency {
        switch selectionMode {
        case .task:
            return urgency
        case let .filter(selectedFilter):
            return selectedFilter.wrappedValue?.urgency ?? .level1
        }
    }

    private var isShowingAllLevels: Bool {
        switch selectionMode {
        case .task:
            return false
        case let .filter(selectedFilter):
            return selectedFilter.wrappedValue == nil
        }
    }

    private var summaryChipTitle: String {
        isShowingAllLevels ? "All levels" : derivedPriority.title
    }

    private var summaryChipSystemImage: String {
        isShowingAllLevels ? "line.3.horizontal.decrease.circle" : "flag.fill"
    }

    private var summaryChipColor: Color {
        isShowingAllLevels ? .accentColor : priorityColor(for: derivedPriority)
    }

    private func priorityTitle(
        for importanceLevel: RoutineTaskImportance,
        _ urgencyLevel: RoutineTaskUrgency
    ) -> String {
        let score = importanceLevel.sortOrder + urgencyLevel.sortOrder
        switch score {
        case ..<4:
            return "L"
        case 4...5:
            return "M"
        case 6...7:
            return "H"
        default:
            return "U"
        }
    }

    private func cellColor(
        importanceLevel: RoutineTaskImportance,
        urgencyLevel: RoutineTaskUrgency
    ) -> Color {
        let normalizedImportance = Double(importanceLevel.sortOrder - 1) / 3.0
        let normalizedUrgency = Double(urgencyLevel.sortOrder - 1) / 3.0
        let intensity = min(max((normalizedImportance * 0.55) + (normalizedUrgency * 0.45), 0), 1)

        return Color(
            hue: 0.16 - (0.16 * intensity),
            saturation: 0.35 + (0.45 * intensity),
            brightness: 0.98 - (0.22 * intensity)
        )
    }

    private func priorityColor(for priority: RoutineTaskPriority) -> Color {
        switch priority {
        case .none:
            return .secondary
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }

    @ViewBuilder
    private func summaryChip(
        title: String,
        systemImage: String,
        color: Color = .secondary,
        emphasized: Bool = false
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font((emphasized ? Font.caption.weight(.semibold) : .caption))
            .lineLimit(1)
            .minimumScaleFactor(isCompactWidth ? 0.75 : 0.9)
            .foregroundStyle(emphasized ? color : .primary)
            .padding(.horizontal, isCompactWidth ? 8 : 10)
            .padding(.vertical, 6)
            .background(
                (emphasized ? color.opacity(0.12) : Color.secondary.opacity(0.10)),
                in: Capsule()
            )
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    private var derivedPriority: RoutineTaskPriority {
        let score = displayedImportance.sortOrder + displayedUrgency.sortOrder
        switch score {
        case ..<4:
            return .low
        case 4...5:
            return .medium
        case 6...7:
            return .high
        default:
            return .urgent
        }
    }
}

private extension View {
    func axisLabelBorder() -> some View {
        overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
