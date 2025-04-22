import SwiftUI

struct ImportanceUrgencyMatrixPicker: View {
    @Binding var importance: RoutineTaskImportance
    @Binding var urgency: RoutineTaskUrgency
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let importanceLevels = RoutineTaskImportance.allCases.sorted { $0.sortOrder > $1.sortOrder }
    private let urgencyLevels = RoutineTaskUrgency.allCases.sorted { $0.sortOrder < $1.sortOrder }

    private var derivedPriority: RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Importance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(importance.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                Text("Urgency")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(urgency.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    summaryChip(title: importance.title, systemImage: "star")
                    summaryChip(title: urgency.title, systemImage: "bolt")
                    summaryChip(
                        title: derivedPriority.title,
                        systemImage: "flag.fill",
                        color: priorityColor(for: derivedPriority),
                        emphasized: true
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        summaryChip(title: importance.title, systemImage: "star")
                        summaryChip(title: urgency.title, systemImage: "bolt")
                    }

                    summaryChip(
                        title: derivedPriority.title,
                        systemImage: "flag.fill",
                        color: priorityColor(for: derivedPriority),
                        emphasized: true
                    )
                }
            }
        }
    }

    private func matrixCell(
        importanceLevel: RoutineTaskImportance,
        urgencyLevel: RoutineTaskUrgency
    ) -> some View {
        let isSelected = importance == importanceLevel && urgency == urgencyLevel

        return Button {
            importance = importanceLevel
            urgency = urgencyLevel
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
}
