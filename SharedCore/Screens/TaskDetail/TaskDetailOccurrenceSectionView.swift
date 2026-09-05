import SwiftUI

struct TaskDetailOccurrenceSectionView: View {
    let occurrences: [TaskDetailOccurrencePresentation]
    let onSelect: (Date) -> Void
    let onComplete: (Date) -> Void
    let onMarkMissed: (Date) -> Void
    let onCancel: (Date) -> Void
    let onClearResolution: (Date) -> Void

    private var selectedOccurrence: TaskDetailOccurrencePresentation? {
        occurrences.first(where: \.isSelected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Occurrences")
                    .font(.headline)

                Text("Choose a scheduled time to view or update that occurrence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(occurrences) { occurrence in
                        occurrenceButton(occurrence)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            if let selectedOccurrence {
                selectedOccurrenceActions(selectedOccurrence)
            }
        }
        .padding(16)
        .taskDetailScrollCardSurface(
            cornerRadius: 16,
            tint: .secondary,
            tintOpacity: 0.06,
            stroke: .secondary.opacity(0.18)
        )
    }

    private func occurrenceButton(
        _ occurrence: TaskDetailOccurrencePresentation
    ) -> some View {
        let tint = statusTint(occurrence.status)
        return Button {
            onSelect(occurrence.occurrence)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(occurrence.occurrence.formatted(date: .omitted, time: .shortened))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)

                Label(
                    statusTitle(occurrence.status),
                    systemImage: statusSystemImage(occurrence.status)
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            }
            .frame(minWidth: 104, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(occurrence.isSelected ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        occurrence.isSelected ? tint : tint.opacity(0.28),
                        lineWidth: occurrence.isSelected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(occurrence.occurrence.formatted(date: .omitted, time: .shortened)), \(statusTitle(occurrence.status))"
        )
        .accessibilityAddTraits(occurrence.isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectedOccurrenceActions(
        _ occurrence: TaskDetailOccurrencePresentation
    ) -> some View {
        Divider()

        VStack(alignment: .leading, spacing: 10) {
            Text("Selected: \(occurrence.occurrence.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                if occurrence.canComplete {
                    Button {
                        onComplete(occurrence.occurrence)
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

                if occurrence.canMarkMissed {
                    Button {
                        onMarkMissed(occurrence.occurrence)
                    } label: {
                        Label("Confirm missed", systemImage: "xmark")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                if occurrence.canCancel {
                    Button {
                        onCancel(occurrence.occurrence)
                    } label: {
                        Label("Cancel", systemImage: "slash.circle")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                if occurrence.canClearResolution {
                    Button {
                        onClearResolution(occurrence.resolutionTimestamp ?? occurrence.occurrence)
                    } label: {
                        Label("Clear status", systemImage: "arrow.uturn.backward")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func statusTitle(
        _ status: TaskDetailOccurrencePresentation.Status
    ) -> String {
        switch status {
        case .done:
            return "Done"
        case .missed:
            return "Missed"
        case .canceled:
            return "Canceled"
        case .due:
            return "Ready"
        case .upcoming:
            return "Upcoming"
        }
    }

    private func statusSystemImage(
        _ status: TaskDetailOccurrencePresentation.Status
    ) -> String {
        switch status {
        case .done:
            return "checkmark.circle.fill"
        case .missed:
            return "exclamationmark.circle.fill"
        case .canceled:
            return "slash.circle.fill"
        case .due:
            return "clock.fill"
        case .upcoming:
            return "clock"
        }
    }

    private func statusTint(
        _ status: TaskDetailOccurrencePresentation.Status
    ) -> Color {
        switch status {
        case .done:
            return .green
        case .missed:
            return .red
        case .canceled:
            return .gray
        case .due:
            return .orange
        case .upcoming:
            return .blue
        }
    }
}
