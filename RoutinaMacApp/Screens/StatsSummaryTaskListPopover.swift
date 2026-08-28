import SwiftUI

struct StatsSummaryTaskListPopover: View {
    let presentation: StatsSummaryTaskListPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            if presentation.rows.isEmpty {
                ContentUnavailableView(
                    "No matching tasks",
                    systemImage: "checklist",
                    description: Text("No tasks or focus sources match the current Stats filters and date range.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(presentation.rows.enumerated()), id: \.element.id) { index, row in
                            taskRow(row)

                            if index < presentation.rows.count - 1 {
                                Divider()
                                    .padding(.leading, 46)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 420, height: popoverHeight, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentation.title)
                .font(.headline.weight(.semibold))

            Text(presentation.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func taskRow(_ row: StatsSummaryTaskListRow) -> some View {
        HStack(spacing: 12) {
            Group {
                if let emoji = row.emoji {
                    Text(emoji)
                        .font(.title3)
                } else {
                    Image(systemName: row.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 34, height: 34)
            .routinaGlassCard(cornerRadius: 11, tint: .accentColor, tintOpacity: 0.10)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if let value = row.value {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var popoverHeight: CGFloat {
        min(max(CGFloat(presentation.rows.count) * 58 + 92, 210), 520)
    }
}
