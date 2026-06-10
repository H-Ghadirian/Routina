import SwiftUI

struct TaskFormLinkedEventsContent: View {
    let events: [RoutineEventLinkCandidate]
    let selectedEventIDs: [UUID]
    let onToggleEvent: (UUID) -> Void

    @Environment(\.calendar) private var calendar
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                Text("No events yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Search events", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private var filteredEvents: [RoutineEventLinkCandidate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return events
        }
        return events.filter { event in
            event.displayTitle.localizedCaseInsensitiveContains(query)
                || event.displayEmoji.localizedCaseInsensitiveContains(query)
                || event.dateText(calendar: calendar).localizedCaseInsensitiveContains(query)
        }
    }

    private func eventRow(_ event: RoutineEventLinkCandidate) -> some View {
        let isSelected = selectedEventIDs.contains(event.id)
        return Button {
            onToggleEvent(event.id)
        } label: {
            HStack(spacing: 12) {
                Text(event.displayEmoji)
                    .font(.title3)
                    .frame(width: 30, height: 30)
                    .routinaGlassPill(tint: isSelected ? .accentColor : .secondary, tintOpacity: isSelected ? 0.16 : 0.10)

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

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isSelected ? "Unlink" : "Link") event \(event.displayTitle)")
    }
}

extension RoutineEventLinkCandidate {
    func dateText(calendar: Calendar) -> String {
        RoutineEventDateFormatting.text(
            startedAt: startedAt,
            endedAt: endedAt,
            isAllDay: isAllDay,
            calendar: calendar
        )
    }
}
