import SwiftUI

enum TaskDetailPrioritySummaryLayout {
    case adaptive
    case horizontal
}

struct TaskDetailPriorityDisclosureBox: View {
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    @Binding var isExpanded: Bool
    var summaryLayout: TaskDetailPrioritySummaryLayout = .adaptive
    var matrixMaxWidth: CGFloat?
    let onImportanceChanged: (RoutineTaskImportance) -> Void
    let onUrgencyChanged: (RoutineTaskUrgency) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRIORITY")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        prioritySummaryRow
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                matrixPicker
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle()
    }

    @ViewBuilder
    private var prioritySummaryRow: some View {
        switch summaryLayout {
        case .adaptive:
            ViewThatFits(in: .horizontal) {
                horizontalPrioritySummary
                wrappedPrioritySummary
            }
        case .horizontal:
            horizontalPrioritySummary
        }
    }

    private var horizontalPrioritySummary: some View {
        HStack(alignment: .center, spacing: 8) {
            priorityFlagChip
            importanceChip
            urgencyChip
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var wrappedPrioritySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            priorityFlagChip
            HStack(alignment: .center, spacing: 8) {
                importanceChip
                urgencyChip
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var priorityFlagChip: some View {
        Label(priority.title, systemImage: "flag.fill")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(prioritySummaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(prioritySummaryColor.opacity(0.12), in: Capsule())
    }

    private var importanceChip: some View {
        priorityMetadataChip(
            title: "Importance",
            value: importance.title,
            tint: TaskDetailPriorityPresentation.importanceTint(for: importance)
        )
    }

    private var urgencyChip: some View {
        priorityMetadataChip(
            title: "Urgency",
            value: urgency.title,
            tint: TaskDetailPriorityPresentation.urgencyTint(for: urgency)
        )
    }

    private func priorityMetadataChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var matrixPicker: some View {
        if let matrixMaxWidth {
            priorityMatrixPicker
                .frame(maxWidth: matrixMaxWidth, alignment: .leading)
        } else {
            priorityMatrixPicker
        }
    }

    private var priorityMatrixPicker: some View {
        ImportanceUrgencyMatrixPicker(
            importance: Binding(
                get: { importance },
                set: { onImportanceChanged($0) }
            ),
            urgency: Binding(
                get: { urgency },
                set: { onUrgencyChanged($0) }
            ),
            showsSummaryChip: false
        )
    }

    private var prioritySummaryColor: Color {
        TaskDetailPriorityPresentation.priorityTint(for: priority)
    }
}
