import SwiftUI

struct TaskDetailLinkedEventsSectionView: View {
    let events: [RoutineEventLinkCandidate]
    let background: Color
    let stroke: Color
    let onOpenEvent: (UUID) -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Events")
                        .font(.headline)

                    Text(events.count.formatted())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(events) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: RoutineEventLinkCandidate) -> some View {
        Button {
            onOpenEvent(event.id)
        } label: {
            HStack(spacing: 12) {
                Text(event.displayEmoji)
                    .font(.title3)
                    .frame(width: 30, height: 30)
                    .routinaGlassPill(tint: .accentColor, tintOpacity: 0.13)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.displayTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(event.dateText(calendar: calendar))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(event.displayTitle)")
    }
}

struct TaskDetailLinkedEventPresentation: Identifiable, Equatable {
    let id: UUID
}
