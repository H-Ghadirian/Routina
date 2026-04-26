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
        self._importance = .constant(selectedFilter.wrappedValue?.importance ?? .level2)
        self._urgency = .constant(selectedFilter.wrappedValue?.urgency ?? .level2)
        self.selectionMode = .filter(selectedFilter)
        self.showsSummaryChip = showsSummaryChip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsSummaryChip {
                summaryChip(
                    title: derivedPriority.title,
                    systemImage: "flag.fill",
                    color: priorityColor(for: derivedPriority),
                    emphasized: true
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Importance")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)

                    HStack(spacing: 8) {
                        ForEach(urgencyLevels, id: \.self) { level in
                            Text(level.shortTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                ForEach(importanceLevels, id: \.self) { importanceLevel in
                    HStack(spacing: 8) {
                        Text(importanceLevel.shortTitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)

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

                HStack {
                    Spacer(minLength: 80)
                    Text("Urgency")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                selectedFilter.wrappedValue = selectedFilter.wrappedValue == newCell ? nil : newCell
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
            return selectedFilter.wrappedValue?.importance ?? .level2
        }
    }

    private var displayedUrgency: RoutineTaskUrgency {
        switch selectionMode {
        case .task:
            return urgency
        case let .filter(selectedFilter):
            return selectedFilter.wrappedValue?.urgency ?? .level2
        }
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
