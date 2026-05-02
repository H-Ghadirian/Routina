import SwiftUI

struct TodoStateTimingSectionView: View {
    let summary: TodoStateTimingSummary
    var showPersianDates: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("State Timing")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if let headlineChipText {
                    Label(headlineChipText, systemImage: headlineSystemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headlineTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(headlineTint.opacity(0.12), in: Capsule())
                }
            }

            if let completedAt = summary.completedAt,
               let completedLeadDays = summary.completedLeadDays {
                timingHeroRow(
                    title: completedLeadDays == 0 ? "Done same day" : "Done in \(durationText(completedLeadDays))",
                    subtitle: "Created \(dateText(summary.createdAt)), done \(dateText(completedAt))",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            } else if let currentState = summary.currentState,
                      let currentStateElapsedDays = summary.currentStateElapsedDays {
                timingHeroRow(
                    title: "\(durationText(currentStateElapsedDays)) in \(currentState.displayTitle)",
                    subtitle: summary.currentStateStartedAt.map { "Since \(dateText($0))" } ?? "Since creation",
                    systemImage: currentState.systemImage,
                    tint: tint(for: currentState)
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(summary.stateTotals) { total in
                        stateTotalChip(total)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.stateTotals) { total in
                        stateTotalChip(total)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var headlineChipText: String? {
        if let completedLeadDays = summary.completedLeadDays {
            return compactDurationText(completedLeadDays)
        }
        guard let currentStateElapsedDays = summary.currentStateElapsedDays else { return nil }
        return compactDurationText(currentStateElapsedDays)
    }

    private var headlineSystemImage: String {
        summary.completedLeadDays == nil ? "timer" : "flag.checkered"
    }

    private var headlineTint: Color {
        if summary.completedLeadDays != nil {
            return .green
        }
        return summary.currentState.map(tint(for:)) ?? .secondary
    }

    private func timingHeroRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func stateTotalChip(_ total: TodoStateTimingStateTotal) -> some View {
        HStack(spacing: 5) {
            Image(systemName: total.state.systemImage)
                .font(.caption2.weight(.semibold))
            Text(total.state.displayTitle)
            Text(compactDurationText(total.days))
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .foregroundStyle(tint(for: total.state))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tint(for: total.state).opacity(0.10), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint(for: total.state).opacity(0.16), lineWidth: 1)
        )
    }

    private func durationText(_ days: Int) -> String {
        if days == 0 { return "today" }
        if days == 1 { return "1 day" }
        return "\(days) days"
    }

    private func compactDurationText(_ days: Int) -> String {
        "\(max(days, 0))d"
    }

    private func dateText(_ date: Date) -> String {
        PersianDateDisplay.appendingSupplementaryDate(
            to: date.formatted(date: .abbreviated, time: .omitted),
            for: date,
            enabled: showPersianDates
        )
    }

    private func tint(for state: TodoState) -> Color {
        switch state {
        case .ready:
            return .secondary
        case .inProgress:
            return .blue
        case .blocked:
            return .red
        case .done:
            return .green
        case .paused:
            return .teal
        }
    }
}
